/// Manages cell styles for an XLSX workbook.
// Justification: StyleSheet is only mutated during workbook construction, before save
public final class StyleSheet: @unchecked Sendable {
    private var styles: [CellStyle] = [.general]
    private var fonts: [(bold: Bool, size: Double)] = [(false, 11)]
    private var fills: [String?] = [nil, nil] // 0=none, 1=gray125 (required by Excel)

    /// Registers a cell style and returns its index.
    public func register(_ style: CellStyle) -> Int {
        if let existing = styles.firstIndex(where: {
            $0.numberFormatId == style.numberFormatId
            && $0.bold == style.bold
            && $0.fillColor == style.fillColor
        }) {
            return existing
        }
        let fontId = registerFont(bold: style.bold)
        let fillId = registerFill(color: style.fillColor)
        let idx = styles.count
        styles.append(style)
        _ = (fontId, fillId)
        return idx
    }

    private func registerFont(bold: Bool) -> Int {
        if let existing = fonts.firstIndex(where: { $0.bold == bold }) {
            return existing
        }
        fonts.append((bold, 11))
        return fonts.count - 1
    }

    private func registerFill(color: String?) -> Int {
        if let existing = fills.firstIndex(where: { $0 == color }) {
            return existing
        }
        fills.append(color)
        return fills.count - 1
    }

    /// Generates the styles XML.
    public func toXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        """

        // Fonts
        xml += "<fonts count=\"\(fonts.count)\">"
        for font in fonts {
            xml += "<font>"
            if font.bold { xml += "<b/>" }
            xml += "<sz val=\"\(font.size)\"/>"
            xml += "<name val=\"Calibri\"/>"
            xml += "</font>"
        }
        xml += "</fonts>"

        // Fills
        xml += "<fills count=\"\(fills.count)\">"
        xml += "<fill><patternFill patternType=\"none\"/></fill>"
        xml += "<fill><patternFill patternType=\"gray125\"/></fill>"
        for fill in fills.dropFirst(2) {
            if let color = fill {
                xml += "<fill><patternFill patternType=\"solid\"><fgColor rgb=\"\(color)\"/></patternFill></fill>"
            }
        }
        xml += "</fills>"

        // Borders (minimal)
        xml += "<borders count=\"1\"><border/></borders>"

        // Cell style XFs
        xml += "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>"

        // Cell XFs
        xml += "<cellXfs count=\"\(styles.count)\">"
        for style in styles {
            let fontId = fonts.firstIndex(where: { $0.bold == style.bold }) ?? 0
            let fillId: Int
            if let color = style.fillColor {
                fillId = fills.firstIndex(where: { $0 == color }) ?? 0
            } else {
                fillId = 0
            }
            var attrs = "numFmtId=\"\(style.numberFormatId)\" fontId=\"\(fontId)\" fillId=\"\(fillId)\" borderId=\"0\""
            if style.numberFormatId != 0 { attrs += " applyNumberFormat=\"1\"" }
            if style.bold { attrs += " applyFont=\"1\"" }
            if style.fillColor != nil { attrs += " applyFill=\"1\"" }
            xml += "<xf \(attrs)/>"
        }
        xml += "</cellXfs>"

        xml += "</styleSheet>"
        return xml
    }
}
