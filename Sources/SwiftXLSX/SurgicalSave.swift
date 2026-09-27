import Foundation
import SwiftZIP

extension Workbook {

    /// Saves the workbook, preserving the archive it came from where it can.
    ///
    /// A workbook composed in code is written from the in-memory model, exactly as before. One
    /// read from a file is written by **putting its own archive back** and substituting only
    /// what an edit has made wrong — so charts, themes, pivot caches, external links, comments,
    /// macros and every part type Excel adds in future versions survive, along with the
    /// in-sheet elements this library has never modelled.
    ///
    /// ## Preserved includes parts this library owns
    ///
    /// Regenerating `xl/workbook.xml` produces a correct `<sheets>` list and silently drops
    /// `<calcPr>`, `<bookViews>` and `<externalReferences>`. The last is the table that says
    /// what `[2]` means in `'[2]Oil&Gas'!AZ3`: lose it and the formula survives as a reference
    /// to nothing. Since nothing structural may change (see below), the original is still
    /// correct — so it is preserved rather than rebuilt, and the same goes for the content
    /// types, the relationships, the styles and the shared strings.
    ///
    /// ## What it will not do
    ///
    /// Adding, removing or reordering sheets is refused. Part paths would move, and preserved
    /// relationships, the content types and every unspliced sheet still point at the old ones;
    /// there is no way to renumber them without regenerating the parts this exists to protect.
    ///
    /// - Parameters:
    ///   - strategy: Which strategy to use. Defaults to ``defaultSaveStrategy``.
    ///   - staleValues: What to do about the cached values an edit has invalidated. Defaults
    ///     to ``StaleValuePolicy/markForRecalculation``, which is correct for any workbook
    ///     whose formulas Excel can resolve on its own.
    /// - Returns: The complete `.xlsx` archive as `Data`.
    /// - Throws: ``SaveError/noOriginArchive`` if ``SaveStrategy/surgical`` is asked of a
    ///   workbook composed in code, ``SaveError/structuralChangeUnsupported(reason:)`` if the
    ///   sheets have changed, or an error if the archive cannot be written.
    public func save(strategy: SaveStrategy?,
                     staleValues: StaleValuePolicy = .markForRecalculation) throws -> Data {
        switch strategy ?? defaultSaveStrategy {
        case .generated:
            return try SwiftZIP.ZIPWriter.write(entries: generatedParts())
        case .surgical:
            guard let origin else { throw SaveError.noOriginArchive }
            return try SwiftZIP.ZIPWriter.write(
                entries: surgicalParts(from: origin, staleValues: staleValues))
        }
    }

    /// The archive to write, built from the original one.
    ///
    /// - Parameter origin: Every part of the source archive, in its original order.
    /// - Returns: The parts to write, in that same order, with the edited sheets replaced and
    ///   the stale calculation chain removed.
    /// - Throws: ``SaveError/structuralChangeUnsupported(reason:)`` if the sheets no longer
    ///   correspond to the ones that were read.
    private func surgicalParts(from origin: [ZIPEntry],
                               staleValues: StaleValuePolicy) throws -> [ZIPEntry] {
        // Every sheet must still be one that was read. A sheet added in code has no origin
        // part, and there is nowhere to put it without renumbering parts that preserved
        // relationships point at.
        for sheet in sheets where sheet.originPart == nil {
            throw SaveError.structuralChangeUnsupported(
                reason: "sheet '\(sheet.name)' was added after the workbook was read")
        }
        let parts = Set(origin.map(\.path))
        for sheet in sheets {
            guard let part = sheet.originPart, parts.contains(part) else {
                throw SaveError.structuralChangeUnsupported(
                    reason: "sheet '\(sheet.name)' no longer has a part in the archive")
            }
        }

        let edited = sheets.filter(\.hasUnsavedChanges)
        let replacements = try replacementParts(for: edited, origin: origin)
        // The chain records the order Excel last evaluated formulas in. An edit can invalidate
        // it, a wrong one makes Excel repair the file on open, and it is a regenerable cache —
        // so it goes, along with the content-type override that declares it. A declared part
        // that is absent is itself a repair.
        let dropChain = !edited.isEmpty

        // An edit makes every dependent's cached value a lie, and the cells holding them are
        // exactly the ones a splice does not touch. Telling Excel to recalculate is how the
        // file stops claiming numbers nothing computed — unless the caller has declined,
        // which `StaleValuePolicy` explains.
        let markForRecalculation = !edited.isEmpty && staleValues == .markForRecalculation

        var result: [ZIPEntry] = []
        for entry in origin {
            if dropChain, entry.path == Self.calculationChainPart { continue }
            if dropChain, entry.path == "[Content_Types].xml" {
                result.append(ZIPEntry(path: entry.path,
                                       data: Self.withoutCalculationChain(entry.data)))
                continue
            }
            if markForRecalculation, entry.path == "xl/workbook.xml",
               replacements[entry.path] == nil {
                result.append(ZIPEntry(path: entry.path,
                                       data: Self.recalculatingOnLoad(entry.data)))
                continue
            }
            result.append(ZIPEntry(path: entry.path, data: replacements[entry.path] ?? entry.data))
        }
        return result
    }

    /// The part path of the calculation chain.
    private static let calculationChainPart = "xl/calcChain.xml"

    /// New bytes for each edited sheet's part, and for any table a splice appended to.
    ///
    /// Each edited sheet's original XML is **edited, not regenerated** — see
    /// ``WorksheetSplicer``. That is what keeps its conditional formatting, its hyperlinks, its
    /// page setup and its `<drawing>` anchor, and it is why the index tables usually do not have
    /// to be written at all: a splice reuses the style and string indices already in the file,
    /// and only touches a table when a genuinely new string or style has to go on the end of it.
    ///
    /// - Parameters:
    ///   - edited: The sheets with unsaved changes.
    ///   - origin: The source archive, for the original XML of each sheet.
    /// - Returns: Part path to bytes.
    /// - Throws: ``SaveError/spliceFailed(part:reason:)`` if a sheet's part cannot be named,
    ///   is not a worksheet, or holds an edit that would break a cell the caller never touched.
    private func replacementParts(for edited: [Worksheet],
                                  origin: [ZIPEntry]) throws -> [String: Data] {
        var replacements: [String: Data] = [:]
        var appendedSharedString = false
        // Carried from one sheet's splice to the next: two sheets each adding a styled cell
        // must append to the same table, not each to the original.
        var styles = origin.first { $0.path == "xl/styles.xml" }
            .map { String(decoding: $0.data, as: UTF8.self) }
        var appendedStyles = false

        for sheet in edited {
            guard let part = sheet.originPart else {
                throw SaveError.spliceFailed(part: sheet.name,
                                             reason: "the sheet has no part in the archive")
            }
            // **Not every tab is a worksheet.** A chart sheet is a `<sheet>` entry pointing at
            // `xl/chartsheets/sheetN.xml`, and the reader has no parser for one, so it arrives
            // looking like an ordinary empty worksheet — first in the tab order, in the corpus
            // workbook this was found in. Writing worksheet XML over that part would replace a
            // chart with a blank grid, so an edit to one is refused instead.
            guard part.hasPrefix("xl/worksheets/") else {
                throw SaveError.spliceFailed(
                    part: part,
                    reason: "'\(sheet.name)' is not a worksheet — this library can read its "
                        + "cells but cannot write the part back")
            }
            guard let entry = origin.first(where: { $0.path == part }) else {
                throw SaveError.spliceFailed(part: part,
                                             reason: "the part is not in the archive")
            }

            let splicer = WorksheetSplicer(part: part,
                                           original: String(decoding: entry.data, as: UTF8.self))
            let result = try splicer.spliced(edits(of: sheet),
                                             sharedStrings: sharedStrings,
                                             styles: styles)
            replacements[part] = Data(result.xml.utf8)
            appendedSharedString = appendedSharedString || result.appendedSharedString
            if let appended = result.styles {
                styles = appended
                appendedStyles = true
            }
        }

        // Both tables are append-only on this path: the reader loaded them from the file, so
        // every index a copied-through sheet still holds keeps its meaning.
        if appendedSharedString {
            replacements["xl/sharedStrings.xml"] = Data(sharedStrings.toXML().utf8)
        }
        // The file's own part with one `<xf>` on the end, never this library's regeneration of
        // it: `StyleSheet.toXML()` models a fraction of what a real styles part holds, so
        // rewriting it would keep every index and flatten what they point at.
        if appendedStyles, let styles {
            replacements["xl/styles.xml"] = Data(styles.utf8)
        }
        return replacements
    }

    /// The edits a worksheet has recorded, as the splicer wants them.
    private func edits(of sheet: Worksheet) -> [WorksheetSplicer.Edit] {
        sheet.changedCells.compactMap { reference in
            guard let entry = sheet.entry(at: reference.reference) else { return nil }
            return WorksheetSplicer.Edit(reference: reference,
                                         value: entry.0, style: entry.1)
        }
    }

    /// The workbook part, with `<calcPr>` told to recalculate everything on open.
    ///
    /// Three shapes to handle, and the third is why this is not a string replacement:
    ///
    /// - `<calcPr calcId="191029"/>` — add the attribute, keep the others.
    /// - `<calcPr … fullCalcOnLoad="0"/>` — an explicit instruction *not* to recalculate,
    ///   which an edit has just made wrong.
    /// - no `<calcPr>` at all — add one, **before `<extLst>`**. The schema fixes the order of
    ///   a workbook's children, and Excel repairs a file that gets it wrong by deleting what
    ///   it could not place.
    ///
    /// - Parameter data: The original `xl/workbook.xml`.
    /// - Returns: The same XML, recalculating on load.
    private static func recalculatingOnLoad(_ data: Data) -> Data {
        var text = String(decoding: data, as: UTF8.self)
        if let element = text.range(of: "<calcPr[^>]*>", options: .regularExpression) {
            var attributes = String(text[element])
                .replacingOccurrences(of: "<calcPr", with: "")
                .replacingOccurrences(of: "/>", with: "")
                .replacingOccurrences(of: ">", with: "")
            if let existing = attributes.range(of: "\\s*fullCalcOnLoad=\"[^\"]*\"",
                                               options: .regularExpression) {
                attributes.removeSubrange(existing)
            }
            let trimmed = attributes.trimmingCharacters(in: .whitespacesAndNewlines)
            let separator = trimmed.isEmpty ? "" : " "
            text.replaceSubrange(
                element, with: "<calcPr\(separator)\(trimmed) fullCalcOnLoad=\"1\"/>")
            return Data(text.utf8)
        }
        let added = "<calcPr fullCalcOnLoad=\"1\"/>"
        if let extensions = text.range(of: "<extLst") {
            text.insert(contentsOf: added, at: extensions.lowerBound)
            return Data(text.utf8)
        }
        guard let close = text.range(of: "</workbook>") else { return data }
        text.insert(contentsOf: added, at: close.lowerBound)
        return Data(text.utf8)
    }

    /// The content types with the calculation chain's override removed.
    ///
    /// - Parameter data: The original `[Content_Types].xml`.
    /// - Returns: The same XML without the `calcChain` override.
    private static func withoutCalculationChain(_ data: Data) -> Data {
        let text = String(decoding: data, as: UTF8.self)
        guard let range = text.range(of: "<Override[^>]*calcChain[^>]*/>",
                                     options: .regularExpression) else { return data }
        return Data(text.replacingCharacters(in: range, with: "").utf8)
    }
}
