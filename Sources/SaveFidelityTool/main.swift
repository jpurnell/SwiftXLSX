import Foundation
#if canImport(os)
import os
#endif
import SwiftXLSX

/// Measures what `save()` does to a corpus of real workbooks.
///
/// **The pass/fail for `PROPOSAL_surgical_save.md`.** §17 calls the corpus run exactly that,
/// and the run that produced §18 and §19's numbers lived in a throwaway package outside the
/// repository — a gate that cannot be re-run is not a gate, which is why this exists.
///
/// Three questions, one per `--edit` mode:
///
/// - `none` — open a workbook and save it. Every part should come back byte for byte. This is
///   the number that went from 816 parts lost out of 1,440 to zero.
/// - `replace` — overwrite a populated cell. The sheet holding it should change by a handful
///   of bytes and nothing else should move at all.
/// - `insert` — write past the end of the sheet, forcing a new `<row>` and a wider
///   `<dimension>`.
///
/// ```
/// swift run save-fidelity ~/Documents --edit replace --out splice.tsv
/// ```
///
/// ## An executable, a row at a time, and the file is the resume state
///
/// The same shape as this family's other corpus tools, for the same reasons they arrived at
/// it. A run over thousands of workbooks cannot be a test: a test prints only at the end,
/// cannot resume, and gives no way to tell a working run from a hung one. So: a row per
/// workbook, flushed as it goes, and a re-run skips what the output file already holds.
///
/// **A workbook that kills the process is a finding, not an obstacle.** One corpus file took
/// ten minutes and two separate runs stalled on the same one. The path being examined is
/// written to a marker file *before* the file is opened, so the next run knows which workbook
/// its predecessor was holding and steps past it. A row cannot be written for a run that died
/// before the row existed.
///
/// The marker says where a run ended, not what ended it: a workbook that traps and a workbook
/// being read when somebody presses ctrl-C look identical from the next run's side.
struct FidelityRun {

    let root: URL
    let output: URL
    let marker: URL
    let edit: Measurement.Edit
    let progressEvery: Int
    let limit: Int?

    /// Standardises every path before anything touches the filesystem, so a `..` in an
    /// argument is resolved once here rather than honoured repeatedly further down.
    init(root: URL, output: URL, marker: URL, edit: Measurement.Edit,
         progressEvery: Int, limit: Int?) {
        self.root = root.standardizedFileURL
        self.output = output.standardizedFileURL
        self.marker = marker.standardizedFileURL
        self.edit = edit
        self.progressEvery = progressEvery
        self.limit = limit
    }

    func run() throws {
        let all = try workbooks()
        let done = completed()
        let remaining = all.filter { !done.contains($0) }
        let batch = limit.map { Array(remaining.prefix($0)) } ?? remaining

        report("\(all.count) workbooks under \(root.path)")
        report("\(done.count) already measured, \(batch.count) to go, edit: \(edit.rawValue)")
        guard !batch.isEmpty else {
            say("nothing to do")
            return
        }

        let handle = try openOutput()
        defer { try? handle.close() }

        var rows: [String] = []
        for (index, path) in batch.enumerated() {
            mark(path)
            // Each workbook's archives, parsed model and re-parsed output are released before
            // the next one is opened. Without this the run accumulated enough that the system
            // killed it for memory 1,384 workbooks in.
            let row = autoreleasepool { Measurement(path: path, edit: edit).row(under: root) }
            handle.write(Data((row + "\n").utf8))
            flush(handle, after: path)
            rows.append(row)
            unmark(after: path)
            if (index + 1) % progressEvery == 0 {
                report("\(index + 1)/\(batch.count)")
            }
        }
        summarise(rows)
    }

    // MARK: - The summary

    /// What the run found, in the form the proposal quotes it in.
    private func summarise(_ rows: [String]) {
        let fields = rows.map { $0.components(separatedBy: "\t") }
        let columns = Measurement.header.components(separatedBy: "\t")
        func value(_ row: [String], _ name: String) -> String {
            guard let index = columns.firstIndex(of: name), index < row.count else { return "" }
            return row[index]
        }
        func number(_ row: [String], _ name: String) -> Int { Int(value(row, name)) ?? 0 }

        let saved = fields.filter { value($0, "outcome") == "saved" }
        var outcomes: [String: Int] = [:]
        for row in fields { outcomes[value(row, "outcome"), default: 0] += 1 }

        say("")
        say("workbooks \(fields.count)   edit \(edit.rawValue)")
        say("  outcomes: " + outcomes.sorted { $0.key < $1.key }
            .map { "\($0.key) \($0.value)" }.joined(separator: ", "))
        guard !saved.isEmpty else { return }

        func tally(_ label: String, _ passing: (([String]) -> Bool)) {
            let count = saved.filter(passing).count
            let mark = count == saved.count ? "✓" : "✗"
            say("  \(mark) \(label): \(count)/\(saved.count)")
        }
        // An edit is *meant* to drop `xl/calcChain.xml`: the chain records the order Excel
        // last evaluated formulas in, a stale one makes Excel repair the file, and it is a
        // regenerable cache. Counting that as a lost part marked 36 correct saves as failures,
        // and a gate that cries wolf is one people learn to skip.
        let expected = edit == .none ? [] : ["xl/calcChain.xml"]
        tally(expected.isEmpty ? "no part lost" : "no part lost but the calculation chain") {
            Set(value($0, "lostPaths").split(separator: ";").map(String.init))
                .subtracting(expected).isEmpty
        }
        if !expected.isEmpty {
            let dropped = saved.filter { value($0, "lostPaths").contains("calcChain") }.count
            say("    (the chain was dropped in \(dropped) of \(saved.count); "
                + "the rest had none to drop)")
        }
        tally("re-readable after saving") { value($0, "rereadable") == "true" }
        tally("the edit reads back") { value($0, "editReadBack") == "true" }
        tally("every other sheet byte-identical") { value($0, "otherSheetsIdentical") == "true" }
        tally("unmodelled elements preserved") {
            number($0, "unmodelledIn") == number($0, "unmodelledOut")
        }
        tally("formula count unchanged") {
            number($0, "formulasIn") == number($0, "formulasOut")
        }
        tally("externalReferences preserved") {
            number($0, "externalRefsIn") == number($0, "externalRefsOut")
        }
        tally("calcPr preserved") { number($0, "calcPrIn") == number($0, "calcPrOut") }
        tally("chartsheets preserved") {
            number($0, "chartsheetsIn") == number($0, "chartsheetsOut")
        }

        let deltas = saved.map { abs(number($0, "sheetBytesDelta")) }.sorted()
        if let median = deltas.isEmpty ? nil : deltas[deltas.count / 2], let worst = deltas.last {
            say("  edited sheet byte delta: median \(median), max \(worst)")
        }
        say("")
        say("every row is in \(output.path)")
    }

    // MARK: - Files

    /// Every `.xlsx` under the root, sorted.
    ///
    /// Sorted because a resumed run must cover the corpus in the same order as the run it
    /// continues; otherwise "already done" and "not yet reached" stop lining up.
    private func workbooks() throws -> [String] {
        guard let walk = FileManager.default.enumerator(atPath: root.path) else {
            throw Failure.cannotWalk(root.path)
        }
        var found: [String] = []
        for case let item as String in walk where item.hasSuffix(".xlsx") {
            // Excel's lock files are not workbooks, and opening one is a parse error with a
            // confusing name.
            guard !item.contains("~$") else { continue }
            found.append(item)
        }
        return found.sorted()
    }

    // MARK: - The marker
    //
    // A trap kills the process without unwinding, so the path being examined is written down
    // *before* the file is opened. Every failure here is reported rather than swallowed: a
    // marker that was not written costs the next run a repeat of a workbook that may kill it
    // again, and one that was not removed costs it a workbook it never measures.

    private func mark(_ path: String) {
        do {
            try path.write(to: marker, atomically: true, encoding: .utf8)
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "marker")
                .error("could not mark \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            report("could not record \(path) in \(marker.lastPathComponent): \(error)")
        }
    }

    private func unmark(after path: String) {
        do {
            try FileManager.default.removeItem(at: marker)
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "marker")
                .error("could not clear the marker after \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            report("could not clear \(marker.lastPathComponent) after \(path): \(error)"
                + " — the next run will step past it")
        }
    }

    private func flush(_ handle: FileHandle, after path: String) {
        do {
            try handle.synchronize()
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "output")
                .error("flush failed after \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            report("flush failed after \(path): \(error)")
        }
    }

    /// The report file, open for appending.
    ///
    /// Opened first and created only if that fails, rather than asked about beforehand. A
    /// file that does not exist yet is the ordinary first run, not an error — and "created
    /// it" and "appended to it" look identical afterwards, so only one of them means the
    /// resume found nothing.
    private func openOutput() throws -> FileHandle {
        do {
            let handle = try FileHandle(forWritingTo: output)
            try handle.seekToEnd()
            return handle
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "output")
                .error("creating the report file: \(String(describing: error), privacy: .public)")
            #endif
            report("creating \(output.lastPathComponent) (\(error))")
        }
        try (Measurement.header + "\n").write(to: output, atomically: true, encoding: .utf8)
        do {
            let handle = try FileHandle(forWritingTo: output)
            try handle.seekToEnd()
            return handle
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "output")
                .error("cannot write the report file: \(String(describing: error), privacy: .public)")
            #endif
            report("cannot write \(output.path): \(error)")
            throw Failure.cannotWrite(output.path)
        }
    }

    private func completed() -> Set<String> {
        let text: String
        do {
            text = try String(contentsOf: output, encoding: .utf8)
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "resume")
                .error("no existing run, starting fresh: \(String(describing: error), privacy: .public)")
            #endif
            report("no existing run at \(output.path), starting fresh (\(error))")
            return []
        }
        var seen = Set(text.split(whereSeparator: \.isNewline).dropFirst()
            .compactMap { $0.split(separator: "\t", maxSplits: 1).first.map(String.init) })
        do {
            let stuck = try String(contentsOf: marker, encoding: .utf8)
            guard !stuck.isEmpty else { return seen }
            report("stepping past \(stuck) — a previous run ended while it was open")
            seen.insert(stuck)
        } catch let failure as CocoaError where failure.code == .fileReadNoSuchFile {
            // No marker is the ordinary case: the previous run finished what it started.
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "marker")
                .debug("no marker: \(String(describing: failure), privacy: .public)")
            #endif
        } catch {
            #if canImport(os)
            Logger(subsystem: "SaveFidelity", category: "marker")
                .error("could not read the marker: \(String(describing: error), privacy: .public)")
            #endif
            report("could not read \(marker.lastPathComponent): \(error)")
        }
        return seen
    }

    enum Failure: Error, CustomStringConvertible {
        case cannotWrite(String)
        case cannotWalk(String)

        var description: String {
            switch self {
            case .cannotWrite(let path): return "cannot write \(path)"
            case .cannotWalk(let path): return "cannot enumerate \(path)"
            }
        }
    }
}

/// Progress, which is this program's logging.
func report(_ message: String) {
    FileHandle.standardError.write(Data(("save-fidelity: " + message + "\n").utf8))
    #if canImport(os)
    // Public privacy: a path the operator named and this program's account of it.
    Logger(subsystem: "SaveFidelity", category: "run")
        .error("\(message, privacy: .public)")
    #endif
}

/// A line of the report, which is this program's output.
func say(_ line: String) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

// MARK: - Arguments

let arguments = CommandLine.arguments
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        return nil
    }
    return arguments[index + 1]
}

guard arguments.count > 1, !arguments[1].hasPrefix("--") else {
    report("""
        usage: save-fidelity <corpus-root> [--edit none|replace|insert] [--out FILE] \
        [--every N] [--limit N]
        """)
    exit(2)
}

let editName = option("--edit") ?? "none"
guard let edit = Measurement.Edit(rawValue: editName) else {
    report("--edit must be one of: "
        + Measurement.Edit.allCases.map(\.rawValue).joined(separator: ", "))
    exit(2)
}

let out = URL(fileURLWithPath: option("--out") ?? "save-fidelity-\(editName).tsv")
do {
    try FidelityRun(
        root: URL(fileURLWithPath: (arguments[1] as NSString).expandingTildeInPath),
        output: out,
        marker: out.deletingPathExtension().appendingPathExtension("marker"),
        edit: edit,
        progressEvery: Int(option("--every") ?? "") ?? 25,
        limit: Int(option("--limit") ?? "")
    ).run()
} catch {
    #if canImport(os)
    Logger(subsystem: "SaveFidelity", category: "run")
        .error("run failed: \(String(describing: error), privacy: .public)")
    #endif
    report("failed: \(error)")
    exit(1)
}
