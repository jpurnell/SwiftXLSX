import Foundation
#if canImport(os)
import os
#endif
import SwiftExcelCore
import SwiftXLSX
import SwiftZIP

/// What a save does to one workbook, measured by doing it.
struct Measurement {

    /// What to change before saving.
    enum Edit: String, CaseIterable {
        /// Nothing. The open-and-save fidelity case: every part should come back unchanged.
        case none
        /// Overwrite the first populated cell of the first worksheet.
        case replace
        /// Write past everything the sheet holds, forcing a new `<row>` and a wider
        /// `<dimension>`.
        case insert
    }

    /// The value written by `.replace` and `.insert`.
    ///
    /// Distinctive enough to find, and not a round number: a value that collides with one
    /// already in the sheet would make "the edit read back" true without the edit landing.
    static let written = 123.456

    /// The in-sheet elements a *regenerated* worksheet drops. A splice keeps them, so these
    /// counts are equal before and after or something is wrong.
    static let unmodelled = [
        "<conditionalFormatting", "<hyperlink", "<pageSetup", "<sheetProtection", "<drawing",
        "<legacyDrawing", "<sheetPr", "<autoFilter", "<mergeCell", "<dataValidation",
        "<printOptions", "<pageMargins", "<extLst", "<tableParts", "<picture", "<phoneticPr",
        "<ignoredErrors", "<customSheetViews",
    ]

    /// The columns of the report, in order.
    static let header = [
        "path", "outcome", "detail", "partsIn", "partsOut", "partsLost", "lostPaths",
        "partsChanged", "editedPart", "sheetBytesDelta", "otherSheetsIdentical",
        "unmodelledIn", "unmodelledOut", "cellsIn", "cellsOut", "formulasIn", "formulasOut",
        "externalRefsIn", "externalRefsOut", "calcPrIn", "calcPrOut",
        "chartsheetsIn", "chartsheetsOut", "dimensionIn", "dimensionOut",
        "rereadable", "editReadBack",
    ].joined(separator: "\t")

    let path: String
    let edit: Edit

    /// Reads the workbook, applies the edit, saves it in memory, and compares the archives.
    ///
    /// Nothing is written to the corpus. A workbook that cannot be read, edited or saved
    /// produces a row saying so rather than stopping the run — a corpus contains files that
    /// are not workbooks, and one of them is not a reason to lose the other forty-nine.
    ///
    /// - Parameter root: The corpus directory `path` is relative to.
    /// - Returns: One tab-separated row.
    func row(under root: URL) -> String {
        func line(_ outcome: String, _ detail: String = "", _ rest: [String] = []) -> String {
            ([path, outcome, detail.replacingOccurrences(of: "\t", with: " ")] + rest)
                .joined(separator: "\t")
        }

        // Every failure below carries its reason into the row. "unreadable" once covered four
        // workbooks that were three different things, and a corpus report that cannot tell
        // them apart sends someone to unzip files by hand.
        let data: Data
        do {
            data = try Data(contentsOf: root.appendingPathComponent(path))
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "read")
                .error("unreadable \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            return line("unreadable", String(describing: error))
        }
        let workbook: Workbook
        let before: [ZIPEntry]
        do {
            workbook = try Workbook(xlsxData: data)
            before = try ZIPReader.read(from: data)
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "read")
                .error("unparsable \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            return line("unparsable", String(describing: error))
        }

        var target: CellRef?
        var editedPart = ""
        if edit != .none {
            // The first worksheet with a cell in it. A chart tab is skipped deliberately:
            // editing one is refused by design, and that refusal is not a splice result.
            guard let sheet = workbook.sheets.first(where: {
                $0.originPart?.hasPrefix("xl/worksheets/") == true && !$0.cellReferences.isEmpty
            }), let part = sheet.originPart else { return line("no editable sheet") }
            editedPart = part
            let reference = Self.target(in: sheet, for: edit)
            sheet.write(Self.written, to: reference.reference)
            target = reference
        }

        let saved: Data
        do {
            saved = try workbook.save()
        } catch let failure as SaveError {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "write")
                .error("refused \(path, privacy: .public): \(String(describing: failure), privacy: .public)")
            #endif
            return line("refused", String(describing: failure))
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "write")
                .error("save threw for \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            return line("threw", String(describing: error))
        }
        let after: [ZIPEntry]
        do {
            after = try ZIPReader.read(from: saved)
        } catch {
            // The archive this package has just written cannot be read back by the reader it
            // was written with, which is worth saying loudly rather than counting.
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "write")
                .error("output unreadable for \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            return line("unreadable output", String(describing: error))
        }

        return line("saved", target?.reference ?? "",
                    comparison(before: before, after: after, saved: saved,
                               editedPart: editedPart, target: target))
    }

    /// Where to write, for an edit that has to land somewhere.
    private static func target(in sheet: Worksheet, for edit: Edit) -> CellRef {
        switch edit {
        case .insert:
            // Two columns and three rows past everything, so a `<row>` has to be created and
            // the `<dimension>` widened. A cell merely past the last *column* might still
            // fall inside an existing row.
            let corner = sheet.lastPopulatedCell ?? CellRef("A1")
            return CellRef(column: corner.column + 2, row: corner.row + 3)
        case .replace, .none:
            let populated = sheet.cellReferences.map { CellRef($0) }
                .sorted { ($0.row, $0.column) < ($1.row, $1.column) }
            return populated.first ?? CellRef("A1")
        }
    }

    // MARK: - Comparing the two archives

    private func comparison(before: [ZIPEntry], after: [ZIPEntry], saved: Data,
                            editedPart: String, target: CellRef?) -> [String] {
        let lost = Set(before.map(\.path)).subtracting(after.map(\.path)).sorted()
        let changed = before.filter { entry in
            after.first { $0.path == entry.path }?.data != entry.data
        }

        let sheetIn = Self.text(before, editedPart)
        let sheetOut = Self.text(after, editedPart)
        // Every worksheet except the edited one must come back byte for byte.
        let others = before.filter {
            $0.path.hasPrefix("xl/worksheets/sheet") && $0.path != editedPart
        }
        let othersIdentical = others.allSatisfy { entry in
            after.first { $0.path == entry.path }?.data == entry.data
        }

        let workbookIn = Self.text(before, "xl/workbook.xml")
        let workbookOut = Self.text(after, "xl/workbook.xml")

        // Counted part by part, never joined. Joining every worksheet into one string cost the
        // first full-corpus run its life: the corpus holds workbooks of eight million cells,
        // and holding two concatenations of those alongside the archives, the parsed model and
        // the re-parsed output was enough for the system to kill the process for memory. Each
        // part is now decoded, counted and released before the next.
        let cellsIn = Self.countAcrossWorksheets("<c[ />]", before)
        let cellsOut = Self.countAcrossWorksheets("<c[ />]", after)
        let formulasIn = Self.countAcrossWorksheets("<f[ >/]", before)
        let formulasOut = Self.countAcrossWorksheets("<f[ >/]", after)

        var rereadable = false
        var readBack = target == nil
        do {
            let reopened = try Workbook(xlsxData: saved)
            rereadable = true
            if let reference = target,
               let sheet = reopened.sheets.first(where: { $0.originPart == editedPart }),
               case .number(let value)? = sheet.cell(at: reference.reference) {
                readBack = abs(value - Self.written) < 1e-9
            }
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "verify")
                .error("not re-readable \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            report("\(path): saved but could not be read back — \(error)")
        }

        return [
            "\(before.count)", "\(after.count)", "\(lost.count)",
            lost.joined(separator: ";"), "\(changed.count)", editedPart,
            "\(sheetOut.utf8.count - sheetIn.utf8.count)", "\(othersIdentical)",
            "\(Self.occurrences(of: Self.unmodelled, in: sheetIn))",
            "\(Self.occurrences(of: Self.unmodelled, in: sheetOut))",
            // A cell element, whatever order its attributes come in: OOXML fixes no order,
            // and a Google Sheets export writes `<c t="s" s="12" r="A1">`. Counting `<c r=`
            // undercounted one corpus input by 6,904 cells and made the writer look as though
            // it were inventing them.
            "\(cellsIn)", "\(cellsOut)",
            // `<f` also prefixes `<filter>`, `<filters>` and `<filterColumn>` — autoFilter
            // criteria, not formulas.
            "\(formulasIn)", "\(formulasOut)",
            "\(Self.occurrences(of: ["<externalReference"], in: workbookIn))",
            "\(Self.occurrences(of: ["<externalReference"], in: workbookOut))",
            "\(Self.occurrences(of: ["<calcPr"], in: workbookIn))",
            "\(Self.occurrences(of: ["<calcPr"], in: workbookOut))",
            "\(before.filter { $0.path.hasPrefix("xl/chartsheets/sheet") }.count)",
            "\(after.filter { $0.path.hasPrefix("xl/chartsheets/sheet") }.count)",
            Self.dimension(of: sheetIn), Self.dimension(of: sheetOut),
            "\(rereadable)", "\(readBack)",
        ]
    }

    // MARK: - Reading the parts

    private static func text(_ entries: [ZIPEntry], _ part: String) -> String {
        guard !part.isEmpty, let entry = entries.first(where: { $0.path == part }) else {
            return ""
        }
        return String(decoding: entry.data, as: UTF8.self)
    }

    /// Matches of a pattern across every worksheet part, summed without ever holding more
    /// than one part's text at a time.
    private static func countAcrossWorksheets(_ pattern: String, _ entries: [ZIPEntry]) -> Int {
        var total = 0
        for entry in entries where entry.path.hasPrefix("xl/worksheets/sheet") {
            autoreleasepool {
                total += matches(pattern, in: String(decoding: entry.data, as: UTF8.self))
            }
        }
        return total
    }

    private static func occurrences(of needles: [String], in text: String) -> Int {
        needles.reduce(0) { $0 + text.components(separatedBy: $1).count - 1 }
    }

    private static func matches(_ pattern: String, in text: String) -> Int {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            // The patterns are literals in this file, so this cannot happen without an edit
            // to them — and silently answering zero would make a broken pattern look like a
            // workbook with no cells in it.
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "pattern")
                .error("pattern does not compile: \(String(describing: error), privacy: .public)")
            #endif
            report("pattern \(pattern) does not compile: \(error)")
            return 0
        }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    /// The `<dimension ref=…>` a sheet declares, or empty if it declares none.
    private static func dimension(of xml: String) -> String {
        guard let match = xml.range(of: "<dimension ref=\"[^\"]*\"",
                                    options: .regularExpression) else { return "" }
        return String(xml[match])
            .replacingOccurrences(of: "<dimension ref=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }
}
