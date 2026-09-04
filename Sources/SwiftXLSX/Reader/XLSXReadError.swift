import Foundation
import SwiftExcelCore

/// Errors that can occur when reading an .xlsx file.
public enum XLSXReadError: Error, Sendable {
    /// The ZIP archive could not be read.
    case zipError(String)                    // LIVE: public API for consumers
    /// A required OOXML part is missing.
    case missingPart(String)                 // LIVE: public API for consumers
    /// XML parsing failed for the given part.
    case xmlParseError(part: String, description: String)  // LIVE: public API for consumers
    /// An unsupported OOXML feature was encountered.
    case unsupportedFeature(String)          // LIVE: public API for consumers
    /// A shared string index is out of range.
    case invalidSharedStringIndex(Int)       // LIVE: public API for consumers
    /// A style index references a non-existent style.
    case invalidStyleIndex(Int)              // LIVE: public API for consumers
}
