import Foundation

/// The escape Excel uses for characters XML cannot carry.
///
/// A cell holding a line break is written `Total_x000D__x000A_(net of tax)` in
/// `sharedStrings.xml`. The form is `_xHHHH_`, four hex digits, and it is not an XML entity —
/// the XML parser passes it through as ordinary text, so every reader has to undo it or hand
/// the caller eight characters nobody typed.
///
/// The visible symptom is a report with `_x000D_` in the middle of a label. The invisible one
/// is worse: a lookup key, a `SUMIF` criterion or an equality test carrying those characters
/// matches nothing, and answers zero while looking right — which is how this package's other
/// name-reading defect cost 1,058 cells in one workbook.
///
/// ## The escape for the escape
///
/// A cell whose text really is `_x000D_` is written `_x005F_x000D_`, because `_x005F_` is an
/// underscore. Decoding left to right handles that without a special case: the `_x005F_`
/// becomes `_`, and scanning continues *after* it, so the `x000D_` that follows is ordinary
/// text. A pass that decoded innermost-first, or ran twice, would turn it into a carriage
/// return and lose the difference for good.
enum XMLText {

    /// Undoes Excel's `_xHHHH_` escapes.
    ///
    /// - Parameter text: the text as the XML parser delivered it.
    /// - Returns: the text with each escape replaced by the character it names.
    static func decoded(_ text: String) -> String {
        // Nothing to do, and the common case by a wide margin: most strings hold no
        // underscore at all, and scanning them character by character is wasted work.
        guard text.contains("_x") else { return text }

        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex

        // Bounded: every pass advances `index`, either past one escape or past one character.
        while index < text.endIndex {
            guard let scalar = escape(in: text, at: index) else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }
            result.unicodeScalars.append(scalar.character)
            // Past the escape, not into it — which is what keeps `_x005F_x000D_` an
            // underscore followed by text rather than a carriage return.
            index = scalar.end
        }
        return result
    }

    /// Writes Excel's `_xHHHH_` escapes for characters XML cannot carry.
    ///
    /// The inverse of ``decoded(_:)``, and the half that makes a round trip one: a cell
    /// written with a literal carriage return in it is read back by Excel as a damaged file,
    /// because XML normalises `\r` to `\n` on the way in and the two are different characters
    /// in a spreadsheet.
    ///
    /// An existing `_xHHHH_` in the text is escaped first, as `_x005F_` followed by the rest.
    /// Otherwise a string that happens to read `_x000D_` would come back as a carriage return,
    /// and the round trip would change the document.
    ///
    /// - Parameter text: the text as the caller wrote it.
    /// - Returns: the text with control characters and ambiguous escapes encoded.
    static func encoded(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex

        // Bounded: every pass advances past at least one character.
        while index < text.endIndex {
            // An escape already in the text is made literal, so decoding gives it back
            // unchanged rather than reading it as the character it spells.
            if escape(in: text, at: index) != nil {
                result += "_x005F_"
                index = text.index(after: index)   // past the `_`; the rest is ordinary
                continue
            }
            let character = text[index]
            index = text.index(after: index)
            for scalar in character.unicodeScalars {
                // The C0 controls, which XML cannot carry and Excel therefore escapes.
                if scalar.value < 0x20 {
                    result += "_x\(fourHexDigits(scalar.value))_"
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result
    }

    /// A value as four upper-case hex digits.
    ///
    /// Written out rather than reached through `String(format:)`, which the safety auditor
    /// rejects and is right to: a C format string carries its own type expectations and
    /// nothing checks them against what is passed.
    private static func fourHexDigits(_ value: UInt32) -> String {
        let digits = String(value, radix: 16, uppercase: true)
        return String(repeating: "0", count: max(0, 4 - digits.count)) + digits
    }

    /// The character an escape at this position names, and where it ends.
    private static func escape(
        in text: String, at start: String.Index
    ) -> (character: Unicode.Scalar, end: String.Index)? {
        guard text[start] == "_" else { return nil }
        // `_xHHHH_` is seven characters. A shorter tail cannot hold one.
        guard let end = text.index(start, offsetBy: 7, limitedBy: text.endIndex) else {
            return nil
        }
        let candidate = text[start..<end]
        guard candidate.hasPrefix("_x"), candidate.hasSuffix("_") else { return nil }

        let digits = candidate.dropFirst(2).dropLast()
        guard digits.count == 4, digits.allSatisfy(\.isHexDigit),
              let value = UInt32(digits, radix: 16),
              let scalar = Unicode.Scalar(value) else { return nil }
        return (scalar, end)
    }
}
