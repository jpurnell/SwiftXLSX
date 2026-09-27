import SwiftExcelCore
/// Manages the shared string table for an XLSX workbook.
// Justification: SharedStrings is only mutated during workbook construction, before save
public final class SharedStrings: @unchecked Sendable {
    private var strings: [String] = []
    private var lookup: [String: Int] = [:]

    /// The number of unique strings in the table.
    public var count: Int { strings.count }

    /// Every string, in index order.
    var all: [String] { strings }

    /// Whether the table already holds a string, without adding it.
    ///
    /// For a caller that needs to know whether writing it *would* append — `index(for:)`
    /// answers that question by making it untrue.
    ///
    /// - Parameter string: The string to look for.
    /// - Returns: `true` if it is already in the table.
    func contains(_ string: String) -> Bool { lookup[string] != nil }

    /// Adopts the table read from a file, in file order.
    ///
    /// **Indices are positional, and cells hold the index rather than the string.** A cell
    /// reading `<c t="s"><v>7</v></c>` means "the eighth entry of this table", so a table that
    /// starts empty makes the first string a caller writes index `0` — which in the file
    /// already meant something else. Writing one text cell into a real workbook that way
    /// relabels an unrelated cell, silently, and every sheet copied through unspliced carries
    /// indices into this table.
    ///
    /// Called once by the reader, before anything can ask for an index.
    ///
    /// - Parameter table: The strings, in the order the file stored them.
    func adopt(_ table: [String]) {
        guard strings.isEmpty else { return }
        for string in table {
            if lookup[string] == nil { lookup[string] = strings.count }
            strings.append(string)
        }
    }

    /// Returns the index for a string, adding it if not already present.
    public func index(for string: String) -> Int {
        if let existing = lookup[string] {
            return existing
        }
        let idx = strings.count
        strings.append(string)
        lookup[string] = idx
        return idx
    }

    /// Generates the shared strings XML.
    public func toXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(strings.count)" uniqueCount="\(strings.count)">
        """
        for s in strings {
            // `xml:space="preserve"` because a string may begin or end with a space, and a
            // conforming reader is entitled to strip it without it.
            xml += "<si><t xml:space=\"preserve\">\(escapeXML(XMLText.encoded(s)))</t></si>"
        }
        xml += "</sst>"
        return xml
    }
}

func escapeXML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}
