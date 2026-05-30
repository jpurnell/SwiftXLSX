import Foundation

public final class Workbook: @unchecked Sendable {
    // Justification: Workbook is only mutated during construction, before save
    public private(set) var sheets: [Worksheet] = []
    let sharedStrings = SharedStrings()
    let styleSheet = StyleSheet()

    public init() {}

    @discardableResult
    public func addSheet(name: String) -> Worksheet {
        let sheet = Worksheet(name: name)
        sheets.append(sheet)
        return sheet
    }

    public func save(to url: URL) throws {
        var entries: [(path: String, data: Data)] = []

        entries.append(("[Content_Types].xml", Data(contentTypesXML().utf8)))
        entries.append(("_rels/.rels", Data(relsXML().utf8)))
        entries.append(("xl/workbook.xml", Data(workbookXML().utf8)))
        entries.append(("xl/_rels/workbook.xml.rels", Data(workbookRelsXML().utf8)))
        entries.append(("xl/styles.xml", Data(styleSheet.toXML().utf8)))

        for (i, sheet) in sheets.enumerated() {
            let xml = worksheetXML(sheet: sheet)
            entries.append(("xl/worksheets/sheet\(i + 1).xml", Data(xml.utf8)))
        }

        entries.append(("xl/sharedStrings.xml", Data(sharedStrings.toXML().utf8)))

        try ZIPWriter.write(entries: entries, to: url)
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
            xml += "<row r=\"\(row)\">"
            guard let cellsInRow = rowGroups[row] else { continue }
            for (ref, (value, style)) in cellsInRow {
                let styleId = styleSheet.register(style)
                switch value {
                case .string(let s):
                    let idx = sharedStrings.index(for: s)
                    xml += "<c r=\"\(ref)\" t=\"s\" s=\"\(styleId)\"><v>\(idx)</v></c>"
                case .number(let n):
                    let formatted = n.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", n)
                        : String(n)
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"><v>\(formatted)</v></c>"
                case .formula(let f):
                    let formulaBody = f.hasPrefix("=") ? String(f.dropFirst()) : f
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"><f>\(escapeXML(formulaBody))</f></c>"
                case .date:
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"/>"
                case .blank:
                    xml += "<c r=\"\(ref)\" s=\"\(styleId)\"/>"
                }
            }
            xml += "</row>"
        }
        xml += "</sheetData></worksheet>"
        return xml
    }
}
