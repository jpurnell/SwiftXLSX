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

    /// Saves the workbook as in-memory `.xlsx` data.
    ///
    /// - Returns: The complete `.xlsx` archive as `Data`.
    /// - Throws: An error if the ZIP archive cannot be created.
    public func save() throws -> Data {
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

        return try SwiftZIP.ZIPWriter.write(entries: entries)
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
        xml += "</sheets></workbook>"
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

    private func worksheetXML(sheet: Worksheet) -> String {
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
                let formatted = height.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(height)) : String(height)
                rowAttrs += " ht=\"\(formatted)\" customHeight=\"1\""
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
                    let formatted = n.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(n))
                        : String(n)
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"><v>\(formatted)</v></c>"
                case .bool(let b):
                    xml += "<c r=\"\(ref)\" t=\"b\" s=\"\(styleId)\"><v>\(b ? 1 : 0)</v></c>"
                case .formula(let ast, let cached):
                    let formulaBody: String
                    if case .function("_RAW", let args) = ast,
                       let first = args.first, case .text(let raw) = first {
                        formulaBody = raw
                    } else {
                        formulaBody = FormulaSerializer.serialize(ast)
                    }
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"><f>\(escapeXML(formulaBody))</f>"
                    if let cached = cached {
                        switch cached {
                        case .number(let n):
                            let formatted = n.truncatingRemainder(dividingBy: 1) == 0
                                ? String(Int(n)) : String(n)
                            xml += "<v>\(formatted)</v>"
                        case .text(let s):
                            xml += "<v>\(escapeXML(s))</v>"
                        default:
                            break
                        }
                    }
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

    private func validationXML(range: CellRange, type: ValidationType) -> String {
        let sqref = range.reference
        switch type {
        case .list(let items):
            let joined = items.joined(separator: ",")
            return "<dataValidation type=\"list\" sqref=\"\(sqref)\" allowBlank=\"1\"><formula1>\"\(escapeXML(joined))\"</formula1></dataValidation>"
        case .decimal(let min, let max):
            let minStr = min.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(min)) : String(min)
            let maxStr = max.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(max)) : String(max)
            return "<dataValidation type=\"decimal\" operator=\"between\" sqref=\"\(sqref)\" allowBlank=\"1\"><formula1>\(minStr)</formula1><formula2>\(maxStr)</formula2></dataValidation>"
        case .integer(let min, let max):
            return "<dataValidation type=\"whole\" operator=\"between\" sqref=\"\(sqref)\" allowBlank=\"1\"><formula1>\(min)</formula1><formula2>\(max)</formula2></dataValidation>"
        }
    }
}
