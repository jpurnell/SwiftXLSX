import SwiftExcelCore
/// Manages cell styles for an XLSX workbook.
// Justification: StyleSheet is only mutated during workbook construction, before save
public final class StyleSheet: @unchecked Sendable {
    private var styles: [CellStyle] = [.general]
    private var fonts: [Font] = [Font()]
    private var borders: [Border?] = [nil]
    private var fills: [Fill?] = [nil, Fill(patternType: .gray125)]
    private var numberFormats: [String: Int] = [:]
    private var nextCustomFormatId = 164

    private static let builtinFormats: [String: Int] = [
        "General": 0,
        "#,##0": 3,
        "$#,##0.00": 4,
        "0.00%": 10,
        "mm/dd/yyyy": 14,
    ]

    /// Registers a cell style and returns its index.
    public func register(_ style: CellStyle) -> Int {
        if let existing = styles.firstIndex(of: style) {
            return existing
        }
        _ = registerFont(style.font)
        _ = registerBorder(style.border)
        _ = registerFill(style.fill)
        _ = registerNumberFormat(style.numberFormat)
        styles.append(style)
        return styles.count - 1
    }

    private func registerFont(_ font: Font) -> Int {
        if let existing = fonts.firstIndex(of: font) {
            return existing
        }
        fonts.append(font)
        return fonts.count - 1
    }

    private func registerBorder(_ border: Border?) -> Int {
        if let existing = borders.firstIndex(where: { $0 == border }) {
            return existing
        }
        borders.append(border)
        return borders.count - 1
    }

    private func registerFill(_ fill: Fill?) -> Int {
        if let existing = fills.firstIndex(where: { $0 == fill }) {
            return existing
        }
        fills.append(fill)
        return fills.count - 1
    }

    private func registerNumberFormat(_ format: NumberFormat) -> Int {
        let str = format.formatString
        if let id = Self.builtinFormats[str] {
            return id
        }
        if let id = numberFormats[str] {
            return id
        }
        let id = nextCustomFormatId
        numberFormats[str] = id
        nextCustomFormatId += 1
        return id
    }

    /// Generates the styles XML.
    public func toXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        """

        if !numberFormats.isEmpty {
            xml += "<numFmts count=\"\(numberFormats.count)\">"
            for (formatString, formatId) in numberFormats.sorted(by: { $0.value < $1.value }) {
                xml += "<numFmt numFmtId=\"\(formatId)\" formatCode=\"\(escapeXML(formatString))\"/>"
            }
            xml += "</numFmts>"
        }

        xml += "<fonts count=\"\(fonts.count)\">"
        for font in fonts {
            xml += "<font>"
            if font.bold { xml += "<b/>" }
            if font.italic { xml += "<i/>" }
            if font.underline { xml += "<u/>" }
            xml += "<sz val=\"\(formatSize(font.size))\"/>"
            if let color = font.color {
                xml += "<color rgb=\"\(color)\"/>"
            }
            xml += "<name val=\"\(escapeXML(font.name))\"/>"
            xml += "</font>"
        }
        xml += "</fonts>"

        xml += "<fills count=\"\(fills.count)\">"
        xml += "<fill><patternFill patternType=\"none\"/></fill>"
        xml += "<fill><patternFill patternType=\"gray125\"/></fill>"
        for fill in fills.dropFirst(2) {
            if let fill = fill {
                xml += "<fill><patternFill patternType=\"\(fill.patternType.rawValue)\">"
                if let color = fill.foregroundColor {
                    xml += "<fgColor rgb=\"\(color)\"/>"
                }
                xml += "</patternFill></fill>"
            }
        }
        xml += "</fills>"

        xml += "<borders count=\"\(borders.count)\">"
        for border in borders {
            xml += "<border>"
            xml += borderEdgeXML("left", border?.left)
            xml += borderEdgeXML("right", border?.right)
            xml += borderEdgeXML("top", border?.top)
            xml += borderEdgeXML("bottom", border?.bottom)
            xml += "</border>"
        }
        xml += "</borders>"

        xml += "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>"

        xml += "<cellXfs count=\"\(styles.count)\">"
        for style in styles {
            let fontId = fonts.firstIndex(of: style.font) ?? 0
            let borderId = borders.firstIndex(where: { $0 == style.border }) ?? 0
            let fillId: Int
            if let fill = style.fill {
                fillId = fills.firstIndex(where: { $0 == fill }) ?? 0
            } else {
                fillId = 0
            }
            let numFmtId = resolveNumberFormatId(style.numberFormat)

            var attrs = "numFmtId=\"\(numFmtId)\" fontId=\"\(fontId)\" fillId=\"\(fillId)\" borderId=\"\(borderId)\""
            if numFmtId != 0 { attrs += " applyNumberFormat=\"1\"" }
            if style.font != Font() { attrs += " applyFont=\"1\"" }
            if style.fill != nil { attrs += " applyFill=\"1\"" }
            if style.border != nil { attrs += " applyBorder=\"1\"" }

            if let alignment = style.alignment {
                attrs += " applyAlignment=\"1\""
                xml += "<xf \(attrs)>"
                xml += alignmentXML(alignment)
                xml += "</xf>"
            } else {
                xml += "<xf \(attrs)/>"
            }
        }
        xml += "</cellXfs>"

        xml += "</styleSheet>"
        return xml
    }

    // MARK: - XML Helpers

    private func borderEdgeXML(_ name: String, _ edge: Border.BorderEdge?) -> String {
        guard let edge = edge else {
            return "<\(name)/>"
        }
        return "<\(name) style=\"\(edge.style.rawValue)\"><color rgb=\"\(edge.color)\"/></\(name)>"
    }

    private func alignmentXML(_ alignment: Alignment) -> String {
        var attrs: [String] = []
        if let h = alignment.horizontal { attrs.append("horizontal=\"\(h.rawValue)\"") }
        if let v = alignment.vertical { attrs.append("vertical=\"\(v.rawValue)\"") }
        if alignment.wrapText { attrs.append("wrapText=\"1\"") }
        if alignment.indent > 0 { attrs.append("indent=\"\(alignment.indent)\"") }
        return "<alignment \(attrs.joined(separator: " "))/>"
    }

    private func resolveNumberFormatId(_ format: NumberFormat) -> Int {
        if let id = Self.builtinFormats[format.formatString] {
            return id
        }
        return numberFormats[format.formatString] ?? 0
    }

    private func formatSize(_ size: Double) -> String {
        if size.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(size))
        }
        return String(size)
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
