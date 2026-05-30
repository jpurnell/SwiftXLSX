public final class SharedStrings: @unchecked Sendable {
    // Justification: SharedStrings is only mutated during workbook construction, before save
    private var strings: [String] = []
    private var lookup: [String: Int] = [:]

    public var count: Int { strings.count }

    public func index(for string: String) -> Int {
        if let existing = lookup[string] {
            return existing
        }
        let idx = strings.count
        strings.append(string)
        lookup[string] = idx
        return idx
    }

    public func toXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(strings.count)" uniqueCount="\(strings.count)">
        """
        for s in strings {
            xml += "<si><t>\(escapeXML(s))</t></si>"
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
