import Foundation
import SwiftZIP
import SwiftExcelCore

/// An Excel workbook containing one or more worksheets.
// Justification: Workbook is only mutated during construction, before save
public final class Workbook: @unchecked Sendable {
    /// The worksheets in this workbook.
    public private(set) var sheets: [Worksheet] = []

    /// The workbook's named ranges.
    ///
    /// Empty for a workbook this library built, since the writer defines no names.
    /// Populated when reading a file that has them, so a
    /// ``FormulaAST/namedRange(_:)`` can be resolved to what it points at —
    /// without this the reference is unresolvable rather than inconvenient, and
    /// models route their most important single values through named ranges.
    ///
    /// Resolution is ``NamedRangeCollection``'s: case-insensitive, with a
    /// sheet-scoped name taking precedence over a workbook-scoped one of the same
    /// spelling.
    public private(set) var namedRanges = NamedRangeCollection()

    /// The pivot tables this workbook renders, in the order the sheets were read.
    ///
    /// **Positions and column names, never values.** A pivot's numbers are already written
    /// into cells and cached there, so `GETPIVOTDATA` reads them back off the sheet; these
    /// layouts only say which table a formula means and where its columns are.
    public private(set) var pivotTables: [PivotTableLayout] = []

    /// The archive this workbook was read from, part for part, or `nil` if it was composed
    /// in code.
    ///
    /// Held so that a save can put back what this library does not model — charts, themes,
    /// pivot caches, external links, and every part type Excel adds in future versions. A
    /// workbook with an origin is somebody's file; one without is this library's own output,
    /// and the two cannot safely be saved the same way.
    private(set) var origin: [ZIPEntry]?

    let sharedStrings = SharedStrings()
    let styleSheet = StyleSheet()

    /// Creates an empty workbook.
    public init() {}

    /// Creates a workbook by reading an existing `.xlsx` file.
    ///
    /// Parses the ZIP archive, extracts OOXML parts, and reconstructs
    /// the workbook with cell values, formulas, styles, and layout features.
    ///
    /// - Parameter url: The `.xlsx` file URL.
    /// - Throws: ``XLSXReadError`` if the file is invalid or cannot be parsed.
    public convenience init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(xlsxData: data)
    }

    /// Creates a workbook by reading `.xlsx` data.
    ///
    /// - Parameter data: The raw `.xlsx` file bytes.
    /// - Throws: ``XLSXReadError`` if the data is invalid or cannot be parsed.
    public convenience init(xlsxData data: Data) throws {
        self.init()
        let parsed = try WorkbookReader.read(from: data)
        replaceSheets(parsed.sheets)
        namedRanges = parsed.namedRanges
        // Carried across explicitly, like the two above. The reader populates a workbook of
        // its own and this initializer copies from it field by field, so anything the reader
        // learns and this line does not mention is silently lost — which is exactly what
        // happened to the pivot tables: parsed correctly, adopted correctly, dropped here.
        pivotTables = parsed.pivotTables
        // Taken from the reader rather than re-read from `data`: the reader already unpacked
        // the archive, so parsing it a second time would be both wasted work and a second
        // chance to fail at something that has just succeeded.
        origin = parsed.origin
        // And the string table, for the same reason as the comment above: a cell holds an index
        // into it. Left behind, the first text a caller writes takes index 0 — which the file
        // already uses for something else, so an unrelated cell silently changes its label.
        sharedStrings.adopt(parsed.sharedStrings.all)
        // Reading filled the sheets through the same funnel a caller's `write` goes through.
        // Recording starts *after* that, so a workbook that has been opened and not edited
        // reports no changed cells — otherwise every cell of every file would arrive dirty.
        for sheet in sheets { sheet.beginRecordingChanges() }
    }

    /// Replaces the current sheets with the given array.
    ///
    /// Used internally by ``init(xlsxData:)`` to adopt sheets from a parsed workbook.
    func replaceSheets(_ newSheets: [Worksheet]) {
        sheets = newSheets
    }

    /// Records a named range read from a file.
    ///
    /// - Parameter range: The named range to record.
    func adopt(_ range: NamedRange) {
        namedRanges.add(range)
    }

    /// Records a pivot table layout read from a file.
    ///
    /// - Parameter layout: Where the table sits and what its data fields are called.
    func adopt(_ layout: PivotTableLayout) {
        pivotTables.append(layout)
    }

    /// Records the archive this workbook was read from.
    ///
    /// - Parameter entries: Every part of the source archive, in the order it held them.
    func adopt(origin entries: [ZIPEntry]) {
        origin = entries
    }

    /// Defines a name in this workbook.
    ///
    /// The refers-to text is derived from the target when the file is written, so there is
    /// nothing to keep in step — see `DefinedNameWriter`. A caller needing a form this
    /// package does not parse passes ``NamedRangeTarget/unparsed(_:)`` and says so in the
    /// type, rather than handing the writer a string that shadows a target.
    ///
    /// ```swift
    /// let workbook = Workbook()
    /// workbook.addSheet(name: "Definitions")
    /// workbook.define("taxRate",
    ///                 as: .sheetCell(SheetReference(sheet: "Definitions", cell: CellRef("$C$8"))))
    /// workbook.define("normal", as: .unparsed("_xlfn.LAMBDA(_xlpm.x,_xlpm.x+1)"))
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name, as Excel will show it.
    ///   - target: What the name points at.
    ///   - scope: Workbook-wide, or one sheet.
    ///   - hidden: Whether Excel hides it from the Name Manager.
    ///   - attributes: Attributes this package does not interpret.
    public func define(_ name: String, as target: NamedRangeTarget,
                       scope: NameScope = .workbook, hidden: Bool = false,
                       attributes: [String: String] = [:]) {
        namedRanges.add(NamedRange(name: name, reference: target, scope: scope,
                                   isHidden: hidden, attributes: attributes))
    }

    /// Adds a new worksheet and returns it.
    @discardableResult
    public func addSheet(name: String) -> Worksheet {
        let sheet = Worksheet(name: name)
        sheets.append(sheet)
        return sheet
    }

    /// Saves the workbook as an XLSX file at the given URL.
    public func save(to url: URL) throws {
        let data = try save()
        try data.write(to: url)
    }

    /// Saves the workbook as in-memory `.xlsx` data, using ``defaultSaveStrategy``.
    ///
    /// Surgically if this workbook was read from a file, from the in-memory model if it was
    /// composed in code. ``save(strategy:)`` explains the difference and why it follows
    /// provenance rather than an argument.
    ///
    /// - Returns: The complete `.xlsx` archive as `Data`.
    /// - Throws: ``SaveError/structuralChangeUnsupported(reason:)`` if sheets were added to or
    ///   removed from a workbook that was read, or an error if the archive cannot be written.
    public func save() throws -> Data {
        try save(strategy: nil)
    }

    /// Every part this library writes from its own model, in the order it writes them.
    ///
    /// **The one place that knows the owned set.** `saveManifest(strategy:)` asks this rather
    /// than carrying a list of part paths beside it, so a part added to the writer is in the
    /// owned set without anything to keep in step — and a part this library has never modelled
    /// cannot be mistaken for one it rewrites.
    func generatedParts() -> [ZIPEntry] {
        var entries: [ZIPEntry] = []

        entries.append(ZIPEntry(path: "[Content_Types].xml", data: Data(contentTypesXML().utf8)))
        entries.append(ZIPEntry(path: "_rels/.rels", data: Data(relsXML().utf8)))
        entries.append(ZIPEntry(path: "xl/workbook.xml", data: Data(workbookXML().utf8)))
        entries.append(ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(workbookRelsXML().utf8)))

        // Worksheets must be generated before styles and shared strings
        // because worksheetXML() registers styles and shared string entries.
        for (i, sheet) in sheets.enumerated() {
            let xml = worksheetXML(sheet: sheet)
            entries.append(ZIPEntry(path: "xl/worksheets/sheet\(i + 1).xml", data: Data(xml.utf8)))
        }

        entries.append(ZIPEntry(path: "xl/styles.xml", data: Data(styleSheet.toXML().utf8)))
        entries.append(ZIPEntry(path: "xl/sharedStrings.xml", data: Data(sharedStrings.toXML().utf8)))

        return entries
    }

    // MARK: - XML Generation

    private func contentTypesXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        """
        for i in 1...max(sheets.count, 1) {
            xml += """
            <Override PartName="/xl/worksheets/sheet\(i).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            """
        }
        xml += "</Types>"
        return xml
    }

    private func relsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private func workbookXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        """
        for (i, sheet) in sheets.enumerated() {
            xml += "<sheet name=\"\(escapeXML(sheet.name))\" sheetId=\"\(i + 1)\" r:id=\"rId\(i + 1)\"/>"
        }
        xml += "</sheets>"
        // After `<sheets>` and before anything else: the schema fixes the order, and Excel
        // repairs a file that gets it wrong by deleting what it could not place.
        xml += DefinedNameWriter.element(for: namedRanges.all, sheets: sheets)
        xml += "</workbook>"
        return xml
    }

    private func workbookRelsXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        """
        for i in 0..<sheets.count {
            xml += "<Relationship Id=\"rId\(i + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i + 1).xml\"/>"
        }
        xml += "<Relationship Id=\"rId\(sheets.count + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"
        xml += "<Relationship Id=\"rId\(sheets.count + 2)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings\" Target=\"sharedStrings.xml\"/>"
        xml += "</Relationships>"
        return xml
    }

    /// The XML for one worksheet, generated from the in-memory model.
    ///
    /// Not private because a surgical save regenerates the sheets an edit touched — see
    /// `SurgicalSave.swift`. Step 4 of `PROPOSAL_surgical_save.md` replaces that use with a
    /// splice of the original XML.
    func worksheetXML(sheet: Worksheet) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        """

        if let frozenRef = sheet.frozenPaneRef {
            let pane = CellRef(frozenRef)
            let xSplit = pane.column - 1
            let ySplit = pane.row - 1
            xml += "<sheetViews><sheetView tabSelected=\"1\" workbookViewId=\"0\">"
            xml += "<pane xSplit=\"\(xSplit)\" ySplit=\"\(ySplit)\" topLeftCell=\"\(frozenRef)\" activePane=\"bottomRight\" state=\"frozen\"/>"
            xml += "</sheetView></sheetViews>"
        }

        if !sheet.columnWidths.isEmpty {
            xml += "<cols>"
            for (col, width) in sheet.columnWidths.sorted(by: { $0.key < $1.key }) {
                xml += "<col min=\"\(col)\" max=\"\(col)\" width=\"\(width)\" customWidth=\"1\"/>"
            }
            xml += "</cols>"
        }

        let sortedCells = sheet.cells.sorted { a, b in
            let refA = CellRef(a.key)
            let refB = CellRef(b.key)
            if refA.row != refB.row { return refA.row < refB.row }
            return refA.column < refB.column
        }

        let rowGroups = Dictionary(grouping: sortedCells, by: { CellRef($0.key).row })

        xml += "<sheetData>"
        for row in rowGroups.keys.sorted() {
            var rowAttrs = "r=\"\(row)\""
            if let height = sheet.rowHeights[row] {
                rowAttrs += " ht=\"\(NumberText.of(height))\" customHeight=\"1\""
            }
            xml += "<row \(rowAttrs)>"
            guard let cellsInRow = rowGroups[row] else { continue }
            for (ref, (value, style)) in cellsInRow {
                let styleId = styleSheet.register(style)
                switch value {
                case .text(let s):
                    let idx = sharedStrings.index(for: s)
                    xml += "<c r=\"\(ref)\" t=\"s\" s=\"\(styleId)\"><v>\(idx)</v></c>"
                case .number(let n):
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"><v>\(NumberText.of(n))</v></c>"
                case .bool(let b):
                    xml += "<c r=\"\(ref)\" t=\"b\" s=\"\(styleId)\"><v>\(b ? 1 : 0)</v></c>"
                case .lambda(let parameters, let body, _):
                    // A lambda in a cell is a formula cell, whatever the value says. Excel
                    // writes `<f>_xlfn.LAMBDA(…)</f><v>#CALC!</v>` — the rule in the formula,
                    // and the error that a function is not a value in the cached result.
                    //
                    // The captured frame is deliberately dropped. It is a fact about the
                    // evaluation that produced this value and the file format has nowhere to
                    // put it; a lambda read back from the file closes over the workbook, which
                    // is where it started.
                    let text = FormulaSerializer.serialize(
                        .function("_xlfn.LAMBDA", parameters.map { .namedRange($0) } + [body]))
                    xml += "<c r=\"\(ref)\" t=\"e\" s=\"\(styleId)\">"
                        + "<f>\(escapeXML(text))</f>"
                        + "<v>\(escapeXML(ExcelError.calc.rawValue))</v></c>"
                case .formula(let ast, let cached):
                    // A member of an array formula's span. Excel stores the formula once, at
                    // the anchor, whose `ref` names the rectangle; the other cells of the
                    // span carry **no `<f>` element at all**. `_ARRAY` is this package's
                    // internal mark for a member and is not a function Excel knows, so
                    // serializing it would fill the span with `#NAME?`.
                    //
                    // This wrote an empty `<f/>` until 2026-09-26, on the stated grounds that
                    // Excel does. Excel does not: measured across the corpus, all **32,826**
                    // array-member cells carry no `<f>` and not one carries an empty one. A
                    // member is recovered on read from the anchor's `ref`, so writing nothing
                    // loses nothing — see `ArrayFormulaWriteBackTests`.
                    if case .function("_ARRAY", _) = ast {
                        let member = cachedValueXML(cached)
                        guard !member.value.isEmpty else {
                            xml += "<c r=\"\(ref)\" s=\"\(styleId)\"/>"
                            continue
                        }
                        xml += "<c r=\"\(ref)\"\(member.type) s=\"\(styleId)\">"
                        xml += member.value
                        xml += "</c>"
                        continue
                    }
                    let formulaBody: String
                    if case .function("_RAW", let args) = ast,
                       let first = args.first, case .text(let raw) = first {
                        formulaBody = raw
                    } else {
                        formulaBody = FormulaSerializer.serialize(ast)
                    }
                    // The anchor names the rectangle it fills, which is the only
                    // record that the members belong to it.
                    let arrayAttributes = sheet.arrayFormulas
                        .first { $0.anchor.reference == CellRef(ref).reference }
                        .map { " t=\"array\" ref=\"\($0.span.reference)\"" } ?? ""
                    let recorded = cachedValueXML(cached)
                    xml += "<c r=\"\(ref)\"\(recorded.type) s=\"\(styleId)\">"
                    xml += "<f\(arrayAttributes)>\(escapeXML(formulaBody))</f>"
                    xml += recorded.value
                    xml += "</c>"
                case .error(let e):
                    xml += "<c r=\"\(ref)\" t=\"e\" s=\"\(styleId)\"><v>\(escapeXML(e.rawValue))</v></c>"
                case .date:
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"/>"
                case .blank:
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"/>"
                case .array:
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"/>"
                }
            }
            xml += "</row>"
        }
        xml += "</sheetData>"

        if let filterRange = sheet.autoFilterRange {
            xml += "<autoFilter ref=\"\(filterRange.reference)\"/>"
        }

        if !sheet.mergedCells.isEmpty {
            xml += "<mergeCells count=\"\(sheet.mergedCells.count)\">"
            for range in sheet.mergedCells {
                xml += "<mergeCell ref=\"\(range.reference)\"/>"
            }
            xml += "</mergeCells>"
        }

        if !sheet.validations.isEmpty {
            xml += "<dataValidations count=\"\(sheet.validations.count)\">"
            for validation in sheet.validations {
                xml += validationXML(range: validation.range, type: validation.type)
            }
            xml += "</dataValidations>"
        }

        xml += "</worksheet>"
        return xml
    }

    /// The `<v>` element recording what a formula last evaluated to, if anything.
    ///
    /// Excel stores a cached result for every formula cell, which is what makes a
    /// workbook usable as a test oracle — so it is written back rather than
    /// dropped. Shared by ordinary formulas and by array-formula members, which
    /// have no formula text of their own but do have a value.
    ///
    /// - Parameter cached: The cached value, if the cell has one.
    /// - Returns: The XML fragment, or an empty string.
    private func cachedValueXML(_ cached: CellValue?) -> (type: String, value: String) {
        guard let cached else { return ("", "") }
        switch cached {
        case .number(let number):
            return ("", "<v>\(NumberText.of(number))</v>")
        case .text(let text):
            return (" t=\"str\"", "<v>\(escapeXML(text))</v>")
        case .bool(let flag):
            return (" t=\"b\"", "<v>\(flag ? 1 : 0)</v>")
        case .error(let excelError):
            // A formula that evaluated to an error still has a value, and the cell
            // has to say which kind. Dropping it left `#N/A` reading back as a
            // formula with no result — which is how a mis-sized array formula lost
            // the only evidence that it was mis-sized.
            return (" t=\"e\"", "<v>\(escapeXML(excelError.rawValue))</v>")
        case .lambda:
            // A function is not a value, which is what `#CALC!` says. Excel caches exactly
            // this for a formula that produced a lambda nobody called.
            return (" t=\"e\"", "<v>\(escapeXML(ExcelError.calc.rawValue))</v>")
        case .blank, .date, .formula, .array:
            // Blank is the absence of a cached value; a date is already a number by
            // the time Excel records one; a nested formula or array is not
            // something Excel stores as a cached result at all.
            return ("", "")
        }
    }

    private func validationXML(range: CellRange, type: ValidationType) -> String {
        let sqref = range.reference
        switch type {
        case .list(let items):
            let joined = items.joined(separator: ",")
            return "<dataValidation type=\"list\" sqref=\"\(sqref)\" allowBlank=\"1\"><formula1>\"\(escapeXML(joined))\"</formula1></dataValidation>"
        case .decimal(let min, let max):
            let minStr = NumberText.of(min)
            let maxStr = NumberText.of(max)
            return "<dataValidation type=\"decimal\" operator=\"between\" sqref=\"\(sqref)\" allowBlank=\"1\"><formula1>\(minStr)</formula1><formula2>\(maxStr)</formula2></dataValidation>"
        case .integer(let min, let max):
            return "<dataValidation type=\"whole\" operator=\"between\" sqref=\"\(sqref)\" allowBlank=\"1\"><formula1>\(min)</formula1><formula2>\(max)</formula2></dataValidation>"
        }
    }
}
