import Foundation

enum ZIPWriter {

    static func write(entries: [(path: String, data: Data)], to url: URL) throws {
        var archive = Data()
        var centralDirectory = Data()
        var centralEntryCount: UInt16 = 0

        for entry in entries {
            let localHeaderOffset = UInt32(archive.count)
            let pathData = Data(entry.path.utf8)

            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)

            // Local file header
            var local = Data()
            local.appendUInt32(0x04034b50)       // signature
            local.appendUInt16(20)               // version needed
            local.appendUInt16(0)                // flags
            local.appendUInt16(0)                // compression: stored
            local.appendUInt16(0)                // mod time
            local.appendUInt16(0)                // mod date
            local.appendUInt32(crc)              // CRC-32
            local.appendUInt32(size)             // compressed size
            local.appendUInt32(size)             // uncompressed size
            local.appendUInt16(UInt16(pathData.count)) // name length
            local.appendUInt16(0)                // extra field length
            local.append(pathData)
            local.append(entry.data)
            archive.append(local)

            // Central directory header
            var central = Data()
            central.appendUInt32(0x02014b50)     // signature
            central.appendUInt16(20)             // version made by
            central.appendUInt16(20)             // version needed
            central.appendUInt16(0)              // flags
            central.appendUInt16(0)              // compression: stored
            central.appendUInt16(0)              // mod time
            central.appendUInt16(0)              // mod date
            central.appendUInt32(crc)            // CRC-32
            central.appendUInt32(size)           // compressed size
            central.appendUInt32(size)           // uncompressed size
            central.appendUInt16(UInt16(pathData.count)) // name length
            central.appendUInt16(0)              // extra field length
            central.appendUInt16(0)              // comment length
            central.appendUInt16(0)              // disk number start
            central.appendUInt16(0)              // internal attributes
            central.appendUInt32(0)              // external attributes
            central.appendUInt32(localHeaderOffset) // relative offset
            central.append(pathData)
            centralDirectory.append(central)
            centralEntryCount += 1
        }

        let centralDirOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        let centralDirSize = UInt32(centralDirectory.count)

        // End of central directory record
        var eocd = Data()
        eocd.appendUInt32(0x06054b50)            // signature
        eocd.appendUInt16(0)                     // disk number
        eocd.appendUInt16(0)                     // disk with central dir
        eocd.appendUInt16(centralEntryCount)     // entries on disk
        eocd.appendUInt16(centralEntryCount)     // total entries
        eocd.appendUInt32(centralDirSize)        // central dir size
        eocd.appendUInt32(centralDirOffset)      // central dir offset
        eocd.appendUInt16(0)                     // comment length
        archive.append(eocd)

        try archive.write(to: url)
    }

    // MARK: - CRC-32

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crcTable[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Data Helpers

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        let le = value.littleEndian
        append(UInt8(le & 0xFF))
        append(UInt8((le >> 8) & 0xFF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        let le = value.littleEndian
        append(UInt8(le & 0xFF))
        append(UInt8((le >> 8) & 0xFF))
        append(UInt8((le >> 16) & 0xFF))
        append(UInt8((le >> 24) & 0xFF))
    }
}
