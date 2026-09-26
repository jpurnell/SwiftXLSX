import Foundation
import SwiftZIP

/// How ``Workbook/save()`` builds the archive.
///
/// The two cases are not preferences. One is correct for a workbook this library composed and
/// destructive for one it opened; the other is the reverse. ``Workbook/defaultSaveStrategy``
/// picks between them from provenance, so the destructive path cannot be reached by forgetting
/// an argument.
public enum SaveStrategy: Sendable, Equatable {

    /// Emit only the parts this library models, from its in-memory model.
    ///
    /// Correct for a workbook composed in code. For one that was read from a file this
    /// discards every part the library does not model — measured over a fifty-workbook corpus
    /// sample, 57% of all parts, including charts, themes, pivot caches and external links.
    case generated

    /// Preserve every part of the source archive, splicing only changed cells into the sheets
    /// that contain them.
    ///
    /// Requires a workbook read from a file; ``SaveError/noOriginArchive`` otherwise.
    case surgical
}

/// What a save will do, part by part.
///
/// Public because a caller about to overwrite somebody's model should be able to show them
/// what will happen to it first — and because "which parts survive" is the question this
/// library got wrong silently for long enough to be worth making answerable.
public struct SaveManifest: Sendable, Equatable {

    /// One sheet whose XML will be edited in place rather than regenerated.
    public struct Splice: Sendable, Equatable {

        /// The part path, as it appears in the archive.
        public let part: String

        /// The cells whose `<c>` elements will be replaced, in first-write order.
        public let cells: [CellRef]

        /// Creates a splice record.
        ///
        /// - Parameters:
        ///   - part: The part path.
        ///   - cells: The cells to be replaced.
        public init(part: String, cells: [CellRef]) {
            self.part = part
            self.cells = cells
        }
    }

    /// Sheets whose XML will be spliced, with the cells changed in each.
    public let spliced: [Splice]

    /// Parts regenerated wholesale from the in-memory model.
    public let rewritten: [String]

    /// Parts copied through byte for byte. Empty under ``SaveStrategy/generated``, which
    /// copies nothing.
    public let preserved: [String]

    /// Parts deliberately removed.
    ///
    /// `xl/calcChain.xml` and nothing else, today: it records the order Excel last evaluated
    /// formulas in, a wrong one makes Excel repair the file, and it is a regenerable cache.
    public let dropped: [String]

    /// Whether any cell changed, which is what makes the calculation chain and the cached
    /// values stale.
    public let forcesRecalculation: Bool

    /// Creates a manifest.
    ///
    /// - Parameters:
    ///   - spliced: Sheets to be edited in place.
    ///   - rewritten: Parts to be regenerated.
    ///   - preserved: Parts to be copied through.
    ///   - dropped: Parts to be removed.
    ///   - forcesRecalculation: Whether any cell changed.
    public init(spliced: [Splice], rewritten: [String], preserved: [String],
                dropped: [String], forcesRecalculation: Bool) {
        self.spliced = spliced
        self.rewritten = rewritten
        self.preserved = preserved
        self.dropped = dropped
        self.forcesRecalculation = forcesRecalculation
    }
}

/// What can go wrong on the way to writing a file.
public enum SaveError: Error, Sendable, Equatable {

    /// ``SaveStrategy/surgical`` was asked of a workbook composed in code, which has no
    /// source archive to be surgical about.
    case noOriginArchive

    /// The destination exists and `overwriting` was not set.
    case destinationExists(URL)

    /// A sheet was added, removed or reordered, which moves part paths that unspliced sheets
    /// and preserved relationships still point at.
    case structuralChangeUnsupported(reason: String)

    /// The source sheet XML could not be spliced. Carries the part path, so a caller can say
    /// which sheet.
    case spliceFailed(part: String, reason: String)
}

extension Workbook {

    /// ``SaveStrategy/surgical`` if this workbook was read from an archive,
    /// ``SaveStrategy/generated`` if it was composed in code.
    public var defaultSaveStrategy: SaveStrategy {
        origin == nil ? .generated : .surgical
    }

    /// What a save would do to each part, without writing anything.
    ///
    /// ## The owned set comes from the writer
    ///
    /// Which parts are "ours" is asked of `generatedParts()` — the same code that builds the
    /// archive — rather than kept as a list beside it. A list would rot, and the obvious
    /// alternative of recording what the *reader* consumed is wrong in a way that loses data:
    /// the reader reads pivot tables, pivot caches and per-sheet relationships that the writer
    /// does not emit, so it would mark those as rewritten and drop them.
    ///
    /// - Parameter strategy: Which strategy to describe. Defaults to
    ///   ``defaultSaveStrategy``.
    /// - Returns: The manifest.
    /// - Throws: ``SaveError/noOriginArchive`` if ``SaveStrategy/surgical`` is asked of a
    ///   workbook composed in code.
    public func saveManifest(strategy: SaveStrategy? = nil) throws -> SaveManifest {
        let strategy = strategy ?? defaultSaveStrategy
        let edited = sheets.filter(\.hasUnsavedChanges)
        let forcesRecalculation = !edited.isEmpty

        guard strategy == .surgical else {
            return SaveManifest(spliced: [],
                                rewritten: generatedParts().map(\.path),
                                preserved: [],
                                dropped: [],
                                forcesRecalculation: forcesRecalculation)
        }
        guard let origin else { throw SaveError.noOriginArchive }

        let owned = Set(generatedParts().map(\.path))
        let dropped = forcesRecalculation ? ["xl/calcChain.xml"] : []
        let droppedSet = Set(dropped)

        // An edited sheet is spliced rather than regenerated, so its part is neither rewritten
        // nor merely preserved — it is the third thing, and the reason this manifest exists.
        var spliced: [SaveManifest.Splice] = []
        for (index, sheet) in sheets.enumerated() where sheet.hasUnsavedChanges {
            spliced.append(SaveManifest.Splice(part: "xl/worksheets/sheet\(index + 1).xml",
                                               cells: sheet.changedCells))
        }
        let splicedSet = Set(spliced.map(\.part))

        return SaveManifest(
            spliced: spliced,
            rewritten: generatedParts().map(\.path).filter { !splicedSet.contains($0) },
            preserved: origin.map(\.path).filter {
                !owned.contains($0) && !droppedSet.contains($0)
            },
            dropped: dropped,
            forcesRecalculation: forcesRecalculation)
    }
}
