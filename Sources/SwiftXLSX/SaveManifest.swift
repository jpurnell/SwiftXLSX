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

/// What an edit does about the cached values it has just made wrong.
///
/// Every formula cell carries the value Excel last computed for it. A surgical save
/// deliberately leaves untouched cells untouched, so after an edit their caches are stale and
/// nothing in the file says so.
///
/// **Marking is right, except when it is destructive.** §3.3 of the proposal chose
/// `fullCalcOnLoad` unconditionally, and §18.4 amended it: forcing a recalculation is honest
/// when Excel can resolve every function in the file, and ruinous when it cannot. A Risk
/// Solver model opened without the add-in recalculates `_xll.PsiNormal(…)` to `#NAME?` and
/// cascades that through everything downstream — there, the stale cache is worth more than the
/// honest one.
///
/// A caller who *has* an evaluator needs no third case: they write the recomputed values in as
/// ordinary cell edits, and the splice puts them where they belong.
public enum StaleValuePolicy: Sendable, Equatable {

    /// Tell Excel to recalculate everything when it opens the file.
    ///
    /// The default, and correct for any workbook whose formulas Excel knows.
    case markForRecalculation

    /// Leave the calculation settings exactly as they were.
    ///
    /// For a workbook Excel cannot recalculate correctly on its own, and for a caller who
    /// knows the edit changed nothing downstream.
    case untouched
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

    /// Sheets whose XML will be edited in place rather than regenerated, with the cells
    /// changed in each.
    ///
    /// **Empty today.** The splicer is step 4 of `PROPOSAL_surgical_save.md`; until it exists
    /// an edited sheet is regenerated and appears in ``rewritten``. Use ``Worksheet``'s
    /// `changedCells` to see which cells a caller has touched in the meantime.
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

    /// Whether any pending edit writes a string the shared table does not already hold.
    ///
    /// A cell holds an index into that table, so a string that is already there costs nothing
    /// and one that is not has to go on the end of it.
    var appendsASharedString: Bool {
        for sheet in sheets where sheet.hasUnsavedChanges {
            for reference in sheet.changedCells {
                guard case .text(let value)? = sheet.entry(at: reference.reference)?.0,
                      !sharedStrings.contains(value) else { continue }
                return true
            }
        }
        return false
    }

    /// Whether any pending edit puts a style on a cell the file does not already have.
    var appendsAStyle: Bool {
        for sheet in sheets where sheet.hasUnsavedChanges {
            for reference in sheet.changedCells {
                guard let entry = sheet.entry(at: reference.reference), entry.1 != .general,
                      sheet.wasReadFromFile(reference.reference) == false else { continue }
                return true
            }
        }
        return false
    }

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
    /// - Parameters:
    ///   - strategy: Which strategy to describe. Defaults to ``defaultSaveStrategy``.
    ///   - staleValues: What that save would do about the cached values an edit invalidates.
    ///     Takes the same default as ``save(strategy:staleValues:)``, because a manifest that
    ///     described a different save than the one about to happen would be worse than none.
    /// - Returns: The manifest.
    /// - Throws: ``SaveError/noOriginArchive`` if ``SaveStrategy/surgical`` is asked of a
    ///   workbook composed in code.
    public func saveManifest(
        strategy: SaveStrategy? = nil,
        staleValues: StaleValuePolicy = .markForRecalculation
    ) throws -> SaveManifest {
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

        let dropped = forcesRecalculation ? ["xl/calcChain.xml"] : []
        let droppedSet = Set(dropped)

        // A surgical save puts the original archive back, so everything in it is preserved
        // except what an edit has made wrong. That is narrower than "the parts this library
        // owns": `xl/workbook.xml` is owned and is preserved anyway, because regenerating it
        // would drop `<calcPr>`, `<bookViews>` and `<externalReferences>` while producing a
        // `<sheets>` list no different from the one already there.
        //
        // `spliced` is empty until the splicer exists (step 4 of the proposal). An edited
        // sheet is regenerated today, so it is reported as rewritten — saying "spliced" of a
        // part this code rebuilds would be describing a plan rather than an outcome, and the
        // whole point of a manifest is to be shown to someone before they agree to it.
        var rewritten: [String] = []
        for sheet in sheets where sheet.hasUnsavedChanges {
            guard let part = sheet.originPart else { continue }
            rewritten.append(part)
        }
        // A splice reuses the indices already in the file, so the string table is written only
        // when an edit puts a string in it that was not there. Asked precisely rather than
        // assumed: claiming it always changes would overstate the blast radius of every edit,
        // and never claiming it would understate the one edit where it matters.
        if appendsASharedString {
            rewritten.append("xl/sharedStrings.xml")
        }
        // A style index is positional, so a new cell's style is appended to the file's own
        // table. Only a *new* cell can need one: an edited cell keeps the `s` it had, because
        // changing what a cell says is not changing how it looks.
        if appendsAStyle {
            rewritten.append("xl/styles.xml")
        }
        // Marking the file for recalculation edits `<calcPr>`, so the workbook part changes
        // too — and a caller being shown this before agreeing to it should see that.
        if forcesRecalculation, staleValues == .markForRecalculation {
            rewritten.append("xl/workbook.xml")
        }
        let rewrittenSet = Set(rewritten)

        return SaveManifest(
            spliced: [],
            rewritten: rewritten,
            preserved: origin.map(\.path).filter {
                !rewrittenSet.contains($0) && !droppedSet.contains($0)
            },
            dropped: dropped,
            forcesRecalculation: forcesRecalculation)
    }
}
