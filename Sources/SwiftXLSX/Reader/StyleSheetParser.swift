import Foundation
import SwiftExcelCore

/// Intermediate representation of a parsed `xl/styles.xml` stylesheet.
///
/// Stores the raw tables (fonts, fills, borders, number formats) and cell format
/// records (`cellXfs`). Use ``resolve(styleIndex:)`` to build a ``CellStyle``
/// from a zero-based cell style index.
struct ParsedStyleSheet: Sendable {
    /// Custom number formats keyed by format ID (164+).
    var numberFormats: [Int: String] = [:]
    /// Ordered list of fonts as they appear in `<fonts>`.
    var fonts: [Font] = []
    /// Ordered list of fills as they appear in `<fills>`.
    var fills: [Fill?] = []
    /// Ordered list of borders as they appear in `<borders>`.
    var borders: [Border?] = []
    /// Ordered cell format records from `<cellXfs>`.
    var cellFormats: [CellFormatRecord] = []

    /// A single `<xf>` record from `<cellXfs>`.
    struct CellFormatRecord: Sendable {
        let numFmtId: Int
        let fontId: Int
        let fillId: Int
        let borderId: Int
        let alignment: Alignment?
    }

    /// Resolves a zero-based style index into a ``CellStyle``.
    ///
    /// Returns `.general` for out-of-range indices.
    func resolve(styleIndex: Int) -> CellStyle {
        guard styleIndex >= 0, styleIndex < cellFormats.count else { return .general }
        let xf = cellFormats[styleIndex]
        let font = xf.fontId >= 0 && xf.fontId < fonts.count ? fonts[xf.fontId] : Font()
        let border = xf.borderId >= 0 && xf.borderId < borders.count ? borders[xf.borderId] : nil
        let fill = xf.fillId >= 0 && xf.fillId < fills.count ? fills[xf.fillId] : nil
        let numFmt = resolveNumberFormat(xf.numFmtId)
        return CellStyle(font: font, border: border, alignment: xf.alignment,
                         numberFormat: numFmt, fill: fill)
    }

    /// Maps a number format ID to a ``NumberFormat``.
    private func resolveNumberFormat(_ id: Int) -> NumberFormat {
        switch id {
        case 0: return .general
        case 1: return NumberFormat(formatString: "0")
        case 2: return NumberFormat(formatString: "0.00")
        case 3: return NumberFormat(formatString: "#,##0")
        case 4: return NumberFormat(formatString: "$#,##0.00")
        case 9: return NumberFormat(formatString: "0%")
        case 10: return NumberFormat(formatString: "0.00%")
        case 14: return NumberFormat(formatString: "mm/dd/yyyy")
        default:
            if let custom = numberFormats[id] {
                return NumberFormat(formatString: custom)
            }
            return .general
        }
    }
}

/// Parses `xl/styles.xml` from an XLSX archive into a ``ParsedStyleSheet``.
///
/// Uses an `XMLParser` SAX-style state machine to walk through the major
/// sections: `<numFmts>`, `<fonts>`, `<fills>`, `<borders>`, `<cellStyleXfs>`,
/// and `<cellXfs>`. Each section builds its respective table in order.
final class StyleSheetParser: NSObject, XMLParserDelegate {
    private var result = ParsedStyleSheet()

    // MARK: - Section tracking

    private enum Section {
        case none, numFmts, fonts, fills, borders, cellStyleXfs, cellXfs
    }

    private var section: Section = .none

    // MARK: - Font building state

    private var currentFontName = "Calibri"
    private var currentFontSize: Double = 11
    private var currentFontColor: String?
    private var currentFontBold = false
    private var currentFontItalic = false
    private var currentFontUnderline = false
    private var inFont = false

    // MARK: - Fill building state

    private var currentPatternType: String?
    private var currentFgColor: String?
    private var inFill = false
    private var inPatternFill = false

    // MARK: - Border building state

    private var currentBorderTop: Border.BorderEdge?
    private var currentBorderBottom: Border.BorderEdge?
    private var currentBorderLeft: Border.BorderEdge?
    private var currentBorderRight: Border.BorderEdge?
    private var inBorder = false

    private enum BorderSide { case none, left, right, top, bottom }
    private var currentBorderSide: BorderSide = .none
    private var currentBorderStyle: String?
    private var currentBorderColor: String?

    // MARK: - CellXf building state

    private var currentXfNumFmtId = 0
    private var currentXfFontId = 0
    private var currentXfFillId = 0
    private var currentXfBorderId = 0
    private var currentXfAlignment: Alignment?
    private var inXf = false

    // MARK: - Public API

    /// Parses styles XML data into a ``ParsedStyleSheet``.
    static func parse(data: Data) throws -> ParsedStyleSheet {
        guard !data.isEmpty else { return ParsedStyleSheet() }
        let handler = StyleSheetParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = handler
        guard parser.parse() else {
            throw XLSXReadError.xmlParseError(
                part: "styles.xml",
                description: parser.parserError?.localizedDescription ?? "Unknown error"
            )
        }
        return handler.result
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {

        // Section openers
        case "numFmts":
            section = .numFmts
        case "fonts":
            section = .fonts
        case "fills":
            section = .fills
        case "borders":
            section = .borders
        case "cellStyleXfs":
            section = .cellStyleXfs
        case "cellXfs":
            section = .cellXfs

        // Number format entry
        case "numFmt" where section == .numFmts:
            if let idStr = attributeDict["numFmtId"],
               let id = Int(idStr),
               let code = attributeDict["formatCode"] {
                result.numberFormats[id] = code
            }

        // Font entry and children
        case "font" where section == .fonts:
            inFont = true
            currentFontName = "Calibri"
            currentFontSize = 11
            currentFontColor = nil
            currentFontBold = false
            currentFontItalic = false
            currentFontUnderline = false
        case "b" where inFont && section == .fonts:
            currentFontBold = true
        case "i" where inFont && section == .fonts:
            currentFontItalic = true
        case "u" where inFont && section == .fonts:
            currentFontUnderline = true
        case "sz" where inFont && section == .fonts:
            if let valStr = attributeDict["val"],
               let val = Double(valStr) {
                currentFontSize = val
            }
        case "color" where inFont && section == .fonts:
            currentFontColor = attributeDict["rgb"]
        case "name" where inFont && section == .fonts:
            if let val = attributeDict["val"] {
                currentFontName = val
            }

        // Fill entry and children
        case "fill" where section == .fills:
            inFill = true
            currentPatternType = nil
            currentFgColor = nil
        case "patternFill" where inFill && section == .fills:
            inPatternFill = true
            currentPatternType = attributeDict["patternType"]
        case "fgColor" where inPatternFill && section == .fills:
            currentFgColor = attributeDict["rgb"]

        // Border entry and children
        case "border" where section == .borders:
            inBorder = true
            currentBorderTop = nil
            currentBorderBottom = nil
            currentBorderLeft = nil
            currentBorderRight = nil
        case "left" where inBorder && section == .borders:
            currentBorderSide = .left
            currentBorderStyle = attributeDict["style"]
            currentBorderColor = nil
        case "right" where inBorder && section == .borders:
            currentBorderSide = .right
            currentBorderStyle = attributeDict["style"]
            currentBorderColor = nil
        case "top" where inBorder && section == .borders:
            currentBorderSide = .top
            currentBorderStyle = attributeDict["style"]
            currentBorderColor = nil
        case "bottom" where inBorder && section == .borders:
            currentBorderSide = .bottom
            currentBorderStyle = attributeDict["style"]
            currentBorderColor = nil
        case "color" where currentBorderSide != .none && section == .borders:
            currentBorderColor = attributeDict["rgb"]

        // CellXf entry and alignment child
        case "xf" where section == .cellXfs:
            inXf = true
            currentXfNumFmtId = Int(attributeDict["numFmtId"] ?? "0") ?? 0
            currentXfFontId = Int(attributeDict["fontId"] ?? "0") ?? 0
            currentXfFillId = Int(attributeDict["fillId"] ?? "0") ?? 0
            currentXfBorderId = Int(attributeDict["borderId"] ?? "0") ?? 0
            currentXfAlignment = nil
        case "alignment" where inXf && section == .cellXfs:
            let horizontal = attributeDict["horizontal"].flatMap {
                Alignment.Horizontal(rawValue: $0)
            }
            let vertical = attributeDict["vertical"].flatMap {
                Alignment.Vertical(rawValue: $0)
            }
            let wrapText = attributeDict["wrapText"] == "1"
                || attributeDict["wrapText"] == "true"
            let indent = Int(attributeDict["indent"] ?? "0") ?? 0
            currentXfAlignment = Alignment(
                horizontal: horizontal, vertical: vertical,
                wrapText: wrapText, indent: indent
            )

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {

        // Section closers
        case "numFmts":
            if section == .numFmts { section = .none }
        case "fonts":
            if section == .fonts { section = .none }
        case "fills":
            if section == .fills { section = .none }
        case "borders":
            if section == .borders { section = .none }
        case "cellStyleXfs":
            if section == .cellStyleXfs { section = .none }
        case "cellXfs":
            if section == .cellXfs { section = .none }

        // Commit a font
        case "font" where section == .fonts && inFont:
            let font = Font(name: currentFontName, size: currentFontSize,
                            color: currentFontColor, bold: currentFontBold,
                            italic: currentFontItalic, underline: currentFontUnderline)
            result.fonts.append(font)
            inFont = false

        // Commit a fill
        case "patternFill" where section == .fills:
            inPatternFill = false
        case "fill" where section == .fills && inFill:
            let fill: Fill?
            if let pt = currentPatternType,
               let patternType = Fill.PatternType(rawValue: pt) {
                switch patternType {
                case .none:
                    fill = nil
                case .gray125:
                    fill = Fill(patternType: .gray125)
                case .solid:
                    fill = Fill(patternType: .solid, foregroundColor: currentFgColor)
                }
            } else {
                fill = nil
            }
            result.fills.append(fill)
            inFill = false

        // Commit border edges
        case "left" where section == .borders && currentBorderSide == .left:
            currentBorderLeft = buildBorderEdge()
            currentBorderSide = .none
        case "right" where section == .borders && currentBorderSide == .right:
            currentBorderRight = buildBorderEdge()
            currentBorderSide = .none
        case "top" where section == .borders && currentBorderSide == .top:
            currentBorderTop = buildBorderEdge()
            currentBorderSide = .none
        case "bottom" where section == .borders && currentBorderSide == .bottom:
            currentBorderBottom = buildBorderEdge()
            currentBorderSide = .none

        // Commit a border
        case "border" where section == .borders && inBorder:
            let border: Border?
            if currentBorderTop == nil && currentBorderBottom == nil
                && currentBorderLeft == nil && currentBorderRight == nil {
                border = nil
            } else {
                border = Border(top: currentBorderTop, bottom: currentBorderBottom,
                                left: currentBorderLeft, right: currentBorderRight)
            }
            result.borders.append(border)
            inBorder = false

        // Commit a cell format
        case "xf" where section == .cellXfs && inXf:
            let record = ParsedStyleSheet.CellFormatRecord(
                numFmtId: currentXfNumFmtId,
                fontId: currentXfFontId,
                fillId: currentXfFillId,
                borderId: currentXfBorderId,
                alignment: currentXfAlignment
            )
            result.cellFormats.append(record)
            inXf = false

        default:
            break
        }
    }

    // MARK: - Helpers

    /// Builds a ``Border.BorderEdge`` from the current border side state.
    /// Returns nil if no style was specified.
    private func buildBorderEdge() -> Border.BorderEdge? {
        guard let styleStr = currentBorderStyle,
              let style = Border.BorderEdge.Style(rawValue: styleStr) else {
            return nil
        }
        let color = currentBorderColor ?? "FF000000"
        return Border.BorderEdge(style: style, color: color)
    }
}
