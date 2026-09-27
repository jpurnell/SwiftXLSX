import Foundation
import SwiftExcelCore

/// Adds one style to a workbook's own `xl/styles.xml`, on the end, touching nothing that was
/// already there.
///
/// ## Why appending and not adopting
///
/// A style index is positional: `s="7"` means "the eighth `<xf>` of this file's `<cellXfs>`".
/// Two ways of getting a new index are wrong, and both were tried in the design:
///
/// - **Registering into this library's own ``StyleSheet``** hands out index `0`, because the
///   reader never fills it from the file. Every cell already carrying `s="0"` would then be
///   claimed to share a format it does not have.
/// - **Adopting the parsed table and regenerating** keeps the indices and loses what they point
///   at. ``StyleSheet/toXML()`` writes a styles part out of ``CellStyle``, which models a
///   fraction of what a real one holds — gradient fills, theme colours, cell style records,
///   `dxfs`, `tableStyles`, the `extLst` — so the workbook would come back with its formatting
///   flattened to whatever this package understands.
///
/// So the file's part is edited: the new `<xf>` goes on the end of `<cellXfs>`, its font, fill
/// and border on the end of theirs, and every index the file already used still means exactly
/// what it meant. `<numFmts>` is the one collection that is *keyed* rather than positional, so
/// a new custom format takes an id nothing in the file has claimed.
struct StylesAppender {

    /// The formats every file agrees on, so a style using one needs no `<numFmt>` at all.
    ///
    /// Deliberately the same table ``StyleSheet`` resolves against — a style that writes
    /// `numFmtId="10"` into a generated workbook has to mean the same thing in a spliced one.
    static let builtin: [String: Int] = [
        "General": 0, "#,##0": 3, "$#,##0.00": 4, "0.00%": 10, "mm/dd/yyyy": 14,
    ]

    let original: String

    /// The part with `style` appended, and the index the new `<xf>` took.
    ///
    /// - Parameter style: The style to add.
    /// - Returns: The new XML and the index to write into the cell's `s` attribute.
    /// - Throws: ``SaveError/spliceFailed(part:reason:)`` if the part has no `<cellXfs>`, which
    ///   means it is not a styles part this can reason about.
    func appending(_ style: CellStyle) throws -> (xml: String, index: Int) {
        var xml = original
        guard let existing = Self.count(of: "cellXfs", in: xml) else {
            throw SaveError.spliceFailed(part: "xl/styles.xml",
                                         reason: "the part has no <cellXfs> to append to")
        }

        // Each of these appends and answers with the index it landed at. Appending rather than
        // searching for an equal entry: comparing would mean parsing every `<font>` the file
        // holds back into a `CellStyle`, and a font this package cannot express would compare
        // equal to one it can. A duplicate costs a few bytes; a false match costs formatting.
        let fontId = Self.append(Self.fontXML(style.font), to: "fonts", in: &xml)
        let fillId = Self.append(Self.fillXML(style.fill), to: "fills", in: &xml)
        let borderId = Self.append(Self.borderXML(style.border), to: "borders", in: &xml)
        let numberFormatId = Self.numberFormatId(for: style.numberFormat, in: &xml)

        _ = Self.append(Self.xfXML(style, numberFormatId: numberFormatId, fontId: fontId,
                                   fillId: fillId, borderId: borderId),
                        to: "cellXfs", in: &xml)
        return (xml, existing)
    }

    // MARK: - Appending to one collection

    /// What must come *after* each collection, in the order the schema fixes.
    ///
    /// A styleSheet's children are ordered, and Excel repairs a file that gets it wrong by
    /// deleting what it could not place. So a collection the file lacks is created immediately
    /// before the first of its successors that the file does have — `<numFmts>` before
    /// `<fonts>`, not merely somewhere near the top.
    private static let successors: [String: [String]] = [
        "numFmts": ["fonts", "fills", "borders", "cellStyleXfs", "cellXfs"],
        "fonts": ["fills", "borders", "cellStyleXfs", "cellXfs"],
        "fills": ["borders", "cellStyleXfs", "cellXfs"],
        "borders": ["cellStyleXfs", "cellXfs"],
    ]

    /// Puts `fragment` at the end of `<name>…</name>`, bumps its `count`, and answers the
    /// index it took.
    private static func append(_ fragment: String, to name: String, in xml: inout String) -> Int {
        guard let existing = count(of: name, in: xml) else {
            let created = "<\(name) count=\"1\">\(fragment)</\(name)>"
            for successor in successors[name] ?? [] {
                guard let anchor = xml.range(of: "<\(successor)") else { continue }
                xml.insert(contentsOf: created, at: anchor.lowerBound)
                return 0
            }
            guard let close = xml.range(of: "</styleSheet>") else { return 0 }
            xml.insert(contentsOf: created, at: close.lowerBound)
            return 0
        }
        guard let close = xml.range(of: "</\(name)>") else { return existing }
        xml.insert(contentsOf: fragment, at: close.lowerBound)
        replaceCount(of: name, with: existing + 1, in: &xml)
        return existing
    }

    /// The `count` a collection declares, or `nil` if the file has no such collection.
    ///
    /// Read from the attribute rather than by counting children, because that is the number
    /// Excel trusts — and a file whose declared count disagrees with its contents is a file
    /// this should not be quietly re-deriving.
    private static func count(of name: String, in xml: String) -> Int? {
        guard let open = xml.range(of: "<\(name)[^>]*>", options: .regularExpression) else {
            return nil
        }
        let tag = String(xml[open])
        guard let attribute = tag.range(of: "count=\"[0-9]+\"", options: .regularExpression) else {
            return 0
        }
        return Int(String(tag[attribute]).filter(\.isNumber)) ?? 0
    }

    private static func replaceCount(of name: String, with value: Int, in xml: inout String) {
        guard let open = xml.range(of: "<\(name)[^>]*>", options: .regularExpression) else {
            return
        }
        var tag = String(xml[open])
        guard let attribute = tag.range(of: "count=\"[0-9]+\"", options: .regularExpression) else {
            return
        }
        tag.replaceSubrange(attribute, with: "count=\"\(value)\"")
        xml.replaceSubrange(open, with: tag)
    }

    // MARK: - Number formats, which are keyed rather than positional

    /// The id for a number format, appending a `<numFmt>` if the file has no equivalent.
    ///
    /// Custom ids start at 164 by convention, and the first free one here means *free in this
    /// file* — a corpus workbook already uses 164, and reusing it would silently reformat every
    /// cell that points at it.
    private static func numberFormatId(for format: NumberFormat, in xml: inout String) -> Int {
        if let known = builtin[format.formatString] { return known }

        let code = escapeXML(format.formatString)
        // The file may already define exactly this format, in which case say so rather than
        // adding a second entry that means the same thing.
        if let existing = xml.range(of: "<numFmt numFmtId=\"[0-9]+\" formatCode=\"\(NSRegularExpression.escapedPattern(for: code))\"/>",
                                    options: .regularExpression) {
            let tag = String(xml[existing])
            if let idRange = tag.range(of: "numFmtId=\"[0-9]+\"", options: .regularExpression) {
                return Int(String(tag[idRange]).filter(\.isNumber)) ?? 164
            }
        }

        var next = 164
        var search = xml.startIndex
        while let match = xml.range(of: "numFmtId=\"[0-9]+\"", options: .regularExpression,
                                    range: search..<xml.endIndex) {
            let id = Int(String(xml[match]).filter(\.isNumber)) ?? 0
            if id >= next { next = id + 1 }
            search = match.upperBound
        }
        _ = append("<numFmt numFmtId=\"\(next)\" formatCode=\"\(code)\"/>", to: "numFmts",
                   in: &xml)
        return next
    }

    // MARK: - The fragments
    //
    // Written the same way `StyleSheet.toXML()` writes them, because a style must mean the
    // same thing in a generated workbook and a spliced one.

    private static func fontXML(_ font: Font) -> String {
        var xml = "<font>"
        if font.bold { xml += "<b/>" }
        if font.italic { xml += "<i/>" }
        if font.underline { xml += "<u/>" }
        xml += "<sz val=\"\(NumberText.of(font.size))\"/>"
        if let color = font.color { xml += "<color rgb=\"\(color)\"/>" }
        xml += "<name val=\"\(escapeXML(font.name))\"/>"
        return xml + "</font>"
    }

    private static func fillXML(_ fill: Fill?) -> String {
        guard let fill else { return "<fill><patternFill patternType=\"none\"/></fill>" }
        var xml = "<fill><patternFill patternType=\"\(fill.patternType.rawValue)\">"
        if let color = fill.foregroundColor { xml += "<fgColor rgb=\"\(color)\"/>" }
        return xml + "</patternFill></fill>"
    }

    private static func borderXML(_ border: Border?) -> String {
        func edge(_ name: String, _ edge: Border.BorderEdge?) -> String {
            guard let edge else { return "<\(name)/>" }
            return "<\(name) style=\"\(edge.style.rawValue)\">"
                + "<color rgb=\"\(edge.color)\"/></\(name)>"
        }
        return "<border>" + edge("left", border?.left) + edge("right", border?.right)
            + edge("top", border?.top) + edge("bottom", border?.bottom) + "</border>"
    }

    private static func xfXML(_ style: CellStyle, numberFormatId: Int, fontId: Int,
                              fillId: Int, borderId: Int) -> String {
        var attributes = "numFmtId=\"\(numberFormatId)\" fontId=\"\(fontId)\""
            + " fillId=\"\(fillId)\" borderId=\"\(borderId)\" xfId=\"0\""
        if numberFormatId != 0 { attributes += " applyNumberFormat=\"1\"" }
        if style.font != Font() { attributes += " applyFont=\"1\"" }
        if style.fill != nil { attributes += " applyFill=\"1\"" }
        if style.border != nil { attributes += " applyBorder=\"1\"" }
        guard let alignment = style.alignment else { return "<xf \(attributes)/>" }

        attributes += " applyAlignment=\"1\""
        var parts: [String] = []
        if let horizontal = alignment.horizontal {
            parts.append("horizontal=\"\(horizontal.rawValue)\"")
        }
        if let vertical = alignment.vertical { parts.append("vertical=\"\(vertical.rawValue)\"") }
        if alignment.wrapText { parts.append("wrapText=\"1\"") }
        if alignment.indent > 0 { parts.append("indent=\"\(alignment.indent)\"") }
        return "<xf \(attributes)><alignment \(parts.joined(separator: " "))/></xf>"
    }
}
