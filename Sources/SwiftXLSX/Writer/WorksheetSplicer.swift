import Foundation
import SwiftExcelCore

/// Edits the `<c>` elements a caller changed, in a worksheet's original XML, and leaves every
/// other byte where it was.
///
/// ## Why an edit and not a re-serialisation
///
/// A worksheet holds a great deal this library has never modelled: conditional formatting,
/// hyperlinks, page setup, sheet protection, and the `<drawing r:id=…>` element that anchors a
/// chart. Regenerating the part drops all of it, and the chart case is the worst kind of
/// failure — the chart part survives in the archive with nothing pointing at it, so the file
/// opens cleanly with a picture missing.
///
/// Editing the text bounds the risk to the cells the caller actually touched. That is a far
/// smaller thing to be right about than "reproduce an arbitrary worksheet", and it is the one
/// claim worth testing: *nothing else moved.*
///
/// ## What it refuses
///
/// A shared formula stores its text once, on a master cell carrying
/// `<f t="shared" ref="A2:A3" si="0">C1*2</f>`, and its followers carry only
/// `<f t="shared" si="0"/>`. Replacing the master's `<f>` leaves every follower pointing at an
/// `si` whose text is gone — cells the caller never touched, broken silently. The same argument
/// applies to an array formula's anchor, whose `ref` is the only record that its span belongs
/// to it. Both are refused.
struct WorksheetSplicer {

    /// One cell to write.
    struct Edit {
        let reference: CellRef
        let value: CellValue
        let style: CellStyle
    }

    /// What a splice needed from the workbook's tables, so the caller knows which to write out.
    struct Result {
        let xml: String
        /// True if a string was appended to the shared table.
        let appendedSharedString: Bool
        /// True if a style was registered that the file did not already have.
        let registeredStyle: Bool
    }

    let part: String
    let original: String

    /// Applies the edits.
    ///
    /// - Parameters:
    ///   - edits: The cells to write.
    ///   - sharedStrings: The workbook's string table, appended to for a text value.
    ///   - styleSheet: The workbook's style table, appended to for a new cell's style.
    /// - Returns: The new XML and what it needed from those tables.
    /// - Throws: ``SaveError/spliceFailed(part:reason:)`` if the sheet has no `<sheetData>`, or
    ///   if an edit would break a cell the caller did not touch.
    func spliced(_ edits: [Edit], sharedStrings: SharedStrings,
                 styleSheet: StyleSheet) throws -> Result {
        guard let sheetData = Self.element(named: "sheetData", in: original,
                                           from: original.startIndex) else {
            throw SaveError.spliceFailed(part: part, reason: "the sheet has no <sheetData>")
        }
        var state = State(sharedStrings: sharedStrings, styleSheet: styleSheet)
        let body = sheetData.inner.map { String(original[$0]) } ?? ""
        let rewritten = try rewrite(body: body, edits: edits, state: &state)

        var xml = original
        // The inner range of a self-closing `<sheetData/>` is empty, so an insert has to
        // replace the whole element rather than a range inside it.
        if let inner = sheetData.inner {
            xml.replaceSubrange(inner, with: rewritten)
        } else {
            xml.replaceSubrange(sheetData.full, with: "<sheetData>\(rewritten)</sheetData>")
        }
        xml = Self.widenedDimension(in: xml, toCover: edits.map(\.reference))
        return Result(xml: xml, appendedSharedString: state.appendedSharedString,
                      registeredStyle: state.registeredStyle)
    }

    // MARK: - Rows

    /// Applies the edits to the contents of `<sheetData>`, row by row.
    private func rewrite(body: String, edits: [Edit], state: inout State) throws -> String {
        var byRow: [Int: [Edit]] = [:]
        for edit in edits { byRow[edit.reference.row, default: []].append(edit) }

        // Walk the existing rows in order, editing the ones that have edits and inserting any
        // new row before the first existing row that follows it.
        var result = ""
        var cursor = body.startIndex
        var pending = byRow.keys.sorted()

        while let row = Self.element(named: "row", in: body, from: cursor) {
            let number = Self.attribute("r", in: row.attributes).flatMap { Int($0) }
            // Any new row that sorts before this one goes in first, so rows stay in order —
            // out of order, Excel repairs the sheet.
            while let next = pending.first, let number, next < number {
                result += body[cursor..<row.full.lowerBound]
                cursor = row.full.lowerBound
                result += try newRow(next, edits: byRow[next] ?? [], state: &state)
                pending.removeFirst()
            }
            result += body[cursor..<row.full.lowerBound]
            if let number, let rowEdits = byRow[number] {
                result += try edited(row: row, in: body, edits: rowEdits, state: &state)
                pending.removeAll { $0 == number }
            } else {
                result += body[row.full]
            }
            cursor = row.full.upperBound
        }
        result += body[cursor...]
        for row in pending {
            result += try newRow(row, edits: byRow[row] ?? [], state: &state)
        }
        return result
    }

    /// A row that was not in the file.
    private func newRow(_ number: Int, edits: [Edit], state: inout State) throws -> String {
        let cells = try edits.sorted { $0.reference.column < $1.reference.column }
            .map { try cell(for: $0, originalAttributes: nil, state: &state) }
            .joined()
        return "<row r=\"\(number)\">\(cells)</row>"
    }

    /// An existing row, with its edits applied and everything else — its attributes, its
    /// height, its unedited cells — left alone.
    private func edited(row: Element, in body: String, edits: [Edit],
                        state: inout State) throws -> String {
        guard let inner = row.inner else {
            // `<row r="5"/>` — no cells yet, so all of these are inserts.
            let cells = try edits.sorted { $0.reference.column < $1.reference.column }
                .map { try cell(for: $0, originalAttributes: nil, state: &state) }
                .joined()
            return "<row \(row.attributes)>\(cells)</row>"
        }

        var remaining = Dictionary(uniqueKeysWithValues:
            edits.map { ($0.reference.reference, $0) })
        var result = "<row \(row.attributes)>"
        var cursor = inner.lowerBound

        while let element = Self.element(named: "c", in: body, from: cursor),
              element.full.upperBound <= inner.upperBound {
            let reference = Self.attribute("r", in: element.attributes) ?? ""
            let column = CellRef(reference).column
            // Inserts that sort before this cell go in here, keeping column order.
            for edit in remaining.values
                .filter({ $0.reference.column < column })
                .sorted(by: { $0.reference.column < $1.reference.column }) {
                result += try cell(for: edit, originalAttributes: nil, state: &state)
                remaining[edit.reference.reference] = nil
            }
            result += body[cursor..<element.full.lowerBound]
            if let edit = remaining.removeValue(forKey: reference) {
                try refuseIfShared(element, in: body, reference: reference)
                result += try cell(for: edit, originalAttributes: element.attributes,
                                   state: &state)
            } else {
                result += body[element.full]
            }
            cursor = element.full.upperBound
        }
        result += body[cursor..<inner.upperBound]
        for edit in remaining.values.sorted(by: { $0.reference.column < $1.reference.column }) {
            result += try cell(for: edit, originalAttributes: nil, state: &state)
        }
        return result + "</row>"
    }

    // MARK: - Cells

    /// The `<c>` element for one edit.
    ///
    /// - Parameters:
    ///   - edit: The cell to write.
    ///   - originalAttributes: The attributes the cell already had, if it was in the file. Kept
    ///     verbatim so the style index — and the caller's formatting — survives a value change.
    ///   - state: Accumulates what the tables were asked for.
    /// - Returns: The element.
    private func cell(for edit: Edit, originalAttributes: Substring?,
                      state: inout State) throws -> String {
        var attributes: String
        if let originalAttributes {
            // A value edit is not a formatting edit, so the attributes stay as they were —
            // except `t`, which describes the value and therefore changes with it.
            attributes = Self.removingAttribute("t", from: String(originalAttributes))
        } else {
            attributes = "r=\"\(edit.reference.reference)\""
            // **A style index is positional too, and this table is not the file's.** The reader
            // parses `xl/styles.xml` into its own type and never fills the workbook's
            // ``StyleSheet``, so `register` would allocate index 0 for the first style asked
            // for — and index 0 in the file is whatever that file's first format happens to be.
            // Every cell already carrying `s="0"` would be claimed to share a format it does
            // not have. Refusing is the honest answer until the reader loads the table.
            //
            // A new cell written with no style is fine: it gets no `s` attribute, which means
            // the default format, exactly as an unformatted cell in any file does.
            guard edit.style == .general else {
                throw SaveError.spliceFailed(
                    part: part,
                    reason: "\(edit.reference.reference) is a new cell with a style, and this "
                        + "workbook's style table was not read from the file, so a new style "
                        + "index cannot be allocated without colliding with the file's")
            }
        }

        switch edit.value {
        case .formula(let ast, let cached):
            let text: String
            if case .function("_RAW", let arguments) = ast, let first = arguments.first,
               case .text(let raw) = first {
                text = raw
            } else {
                text = FormulaSerializer.serialize(ast)
            }
            // The cached value belonged to the old formula, so it goes unless the caller
            // supplied a new one.
            var type = "", body = ""
            if let cached {
                (type, body) = Self.valueXML(cached, state: &state)
            }
            return "<c \(attributes)\(type)><f>\(escapeXML(text))</f>\(body)</c>"
        case .blank:
            // Excel writes a formatted empty cell as `<c r=… s=…/>`, and an unformatted one
            // not at all. Removing the element would take the formatting with it.
            return attributes.contains(" s=\"") ? "<c \(attributes)/>" : ""
        default:
            let value = Self.valueXML(edit.value, state: &state)
            guard !value.body.isEmpty else { return "<c \(attributes)/>" }
            return "<c \(attributes)\(value.type)>\(value.body)</c>"
        }
    }

    /// The `t` attribute and `<v>` element for a value.
    private static func valueXML(_ value: CellValue,
                                 state: inout State) -> (type: String, body: String) {
        switch value {
        case .number(let number): return ("", "<v>\(NumberText.of(number))</v>")
        case .text(let text):
            let index = state.sharedStrings.index(for: text)
            state.appendedSharedString = true
            return (" t=\"s\"", "<v>\(index)</v>")
        case .bool(let flag): return (" t=\"b\"", "<v>\(flag ? 1 : 0)</v>")
        case .error(let error): return (" t=\"e\"", "<v>\(escapeXML(error.rawValue))</v>")
        default: return ("", "")
        }
    }

    /// Refuses an edit that other cells depend on the text of.
    private func refuseIfShared(_ element: Element, in body: String,
                                reference: String) throws {
        guard let inner = element.inner,
              let formula = Self.element(named: "f", in: body, from: inner.lowerBound),
              formula.full.upperBound <= inner.upperBound else { return }
        let attributes = String(formula.attributes)
        guard attributes.contains("ref=") else { return }
        if attributes.contains("t=\"shared\"") {
            throw SaveError.spliceFailed(
                part: part,
                reason: "\(reference) is the master of a shared formula; its followers carry "
                    + "only its `si` and would be left pointing at nothing")
        }
        if attributes.contains("t=\"array\"") {
            throw SaveError.spliceFailed(
                part: part,
                reason: "\(reference) is the anchor of an array formula over "
                    + "\(Self.attribute("ref", in: formula.attributes) ?? "its span")"
                    + "; the cells it fills would be left stale")
        }
    }

    // MARK: - Dimension

    /// The sheet's `<dimension>`, widened to cover the cells that were written.
    ///
    /// Left alone if the sheet has none: absent is legal, and inventing one is a change nobody
    /// asked for.
    private static func widenedDimension(in xml: String, toCover written: [CellRef]) -> String {
        guard !written.isEmpty,
              let element = element(named: "dimension", in: xml, from: xml.startIndex),
              let reference = attribute("ref", in: element.attributes) else { return xml }

        let bounds = reference.split(separator: ":").map { CellRef(String($0)) }
        guard let start = bounds.first else { return xml }
        let end = bounds.count > 1 ? bounds[1] : start
        let maxColumn = written.map(\.column).reduce(end.column, max)
        let maxRow = written.map(\.row).reduce(end.row, max)
        guard maxColumn > end.column || maxRow > end.row else { return xml }

        let widened = "\(start.reference):\(CellRef(column: maxColumn, row: maxRow).reference)"
        var result = xml
        result.replaceSubrange(element.full, with: "<dimension ref=\"\(widened)\"/>")
        return result
    }

    // MARK: - A very small XML scanner

    /// One element: where it starts and ends, its attribute text, and its contents.
    struct Element {
        let full: Range<String.Index>
        let attributes: Substring
        /// `nil` for a self-closing element.
        let inner: Range<String.Index>?
    }

    /// Finds the next element with the given name at or after `start`.
    ///
    /// Neither `row` nor `c` nests inside itself, so the closing tag can be found by searching
    /// rather than by counting depth. Quoted attribute values are respected, because a `>`
    /// inside one would otherwise end the tag early.
    static func element(named name: String, in text: String,
                        from start: String.Index) -> Element? {
        var search = start
        while let open = text.range(of: "<\(name)", range: search..<text.endIndex) {
            // `<c` must not match `<cols` or `<cfRule`: the name has to end where it ends.
            let next: Character = open.upperBound < text.endIndex ? text[open.upperBound] : ">"
            guard next == " " || next == ">" || next == "/" || next == "\n" || next == "\t" else {
                search = open.upperBound
                continue
            }
            var index = open.upperBound
            var quote: Character?
            while index < text.endIndex {
                let character = text[index]
                if let open = quote {
                    if character == open { quote = nil }
                } else if character == "\"" || character == "'" {
                    quote = character
                } else if character == ">" {
                    break
                }
                index = text.index(after: index)
            }
            guard index < text.endIndex else { return nil }
            let selfClosing = text[text.index(before: index)] == "/"
            let attributeEnd = selfClosing ? text.index(before: index) : index
            let attributes = text[open.upperBound..<attributeEnd]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let attributeRange = text.range(of: attributes, range: open.upperBound..<index)
                ?? open.upperBound..<open.upperBound

            if selfClosing {
                return Element(full: open.lowerBound..<text.index(after: index),
                               attributes: text[attributeRange], inner: nil)
            }
            let contentStart = text.index(after: index)
            guard let close = text.range(of: "</\(name)>",
                                         range: contentStart..<text.endIndex) else { return nil }
            return Element(full: open.lowerBound..<close.upperBound,
                           attributes: text[attributeRange],
                           inner: contentStart..<close.lowerBound)
        }
        return nil
    }

    /// One attribute's value out of an attribute string.
    static func attribute(_ name: String, in attributes: Substring) -> String? {
        guard let key = attributes.range(of: "\(name)=\"") else { return nil }
        guard let end = attributes.range(of: "\"", range: key.upperBound..<attributes.endIndex)
        else { return nil }
        return String(attributes[key.upperBound..<end.lowerBound])
    }

    /// The same attribute string without one attribute.
    static func removingAttribute(_ name: String, from attributes: String) -> String {
        guard let key = attributes.range(of: "\(name)=\""),
              let end = attributes.range(of: "\"", range: key.upperBound..<attributes.endIndex)
        else { return attributes }
        var result = attributes
        result.removeSubrange(key.lowerBound..<end.upperBound)
        return result.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// What the splice asked of the workbook's tables.
    private struct State {
        let sharedStrings: SharedStrings
        let styleSheet: StyleSheet
        var appendedSharedString = false
        var registeredStyle = false
    }
}
