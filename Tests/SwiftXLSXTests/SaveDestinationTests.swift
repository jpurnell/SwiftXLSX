import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore
import SwiftZIP

/// §3.4 of `PROPOSAL_surgical_save.md`: writing over somebody's model requires saying so.
///
/// The dangerous shape is the one this whole feature exists to serve —
/// `Workbook(contentsOf: url)`, edit a cell, `save(to: url)`. That is the natural thing to
/// write and, until now, it overwrote the original in place with no ceremony and no atomicity:
/// a crash or a bug partway through the write left a truncated file where a model used to be.
///
/// **A workbook composed in code is unaffected.** It has no origin, nothing it could destroy
/// belongs to it, and refusing there would break every caller that regenerates a report over
/// yesterday's copy. The guard follows provenance, like the save strategy does.
@Suite
struct SaveDestinationTests {

    // MARK: - A package to read back in

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
        </Types>
        """

    private static let packageRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
        </Relationships>
        """

    private static let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
        """

    private static let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
        </Relationships>
        """

    private static let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData><row r="1"><c r="A1"><v>7</v></c></row></sheetData></worksheet>
        """

    private func package() throws -> Data {
        try ZIPWriter.write(entries: [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(Self.sheet.utf8)),
        ])
    }

    /// A directory of its own per test, removed afterwards.
    private func inTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SaveDestinationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    // MARK: - Refusing

    /// **The shape that makes this necessary.** Open a model, change a cell, write it back
    /// over itself. It is what a caller will reach for first, and it is the one that destroys
    /// the original if anything goes wrong.
    @Test("saving a read workbook over an existing file is refused")
    func refusesToOverwrite() throws {
        try inTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("model.xlsx")
            try package().write(to: url)

            let workbook = try Workbook(contentsOf: url)
            try #require(workbook.sheets.first).write(99.0, to: "A1")
            #expect(throws: SaveError.destinationExists(url)) {
                try workbook.save(to: url)
            }
        }
    }

    /// And the refusal happens **before** anything is written. A guard that fails after
    /// truncating the file is worse than no guard: it destroys the model *and* reports an
    /// error, so the caller believes nothing happened.
    @Test("a refused save leaves the file exactly as it was")
    func aRefusedSaveChangesNothing() throws {
        try inTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("model.xlsx")
            let original = try package()
            try original.write(to: url)

            let workbook = try Workbook(contentsOf: url)
            try #require(workbook.sheets.first).write(99.0, to: "A1")
            #expect(throws: SaveError.self) { try workbook.save(to: url) }

            #expect(try Data(contentsOf: url) == original,
                    "the file on disk was changed by a save that refused")
        }
    }

    // MARK: - Allowing

    @Test("saying so allows it")
    func overwritingAllowsIt() throws {
        try inTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("model.xlsx")
            try package().write(to: url)

            let workbook = try Workbook(contentsOf: url)
            try #require(workbook.sheets.first).write(99.0, to: "A1")
            try workbook.save(to: url, overwriting: true)

            let reopened = try Workbook(contentsOf: url)
            let sheet = try #require(reopened.sheets.first)
            #expect(sheet.cell(at: "A1") == .number(99))
        }
    }

    /// A destination that does not exist yet needs no permission — there is nothing there to
    /// lose, which is the whole basis of the rule.
    @Test("a new path needs no permission")
    func aNewPathIsFine() throws {
        try inTemporaryDirectory { directory in
            let source = directory.appendingPathComponent("model.xlsx")
            try package().write(to: source)
            let destination = directory.appendingPathComponent("copy.xlsx")

            let workbook = try Workbook(contentsOf: source)
            try #require(workbook.sheets.first).write(99.0, to: "A1")
            try workbook.save(to: destination)

            let reopened = try Workbook(contentsOf: destination)
            #expect(try #require(reopened.sheets.first).cell(at: "A1") == .number(99))
            #expect(try Data(contentsOf: source) == (try package()),
                    "the file it was read from must not have been touched")
        }
    }

    /// **A workbook composed in code is not covered.** It has no origin, so there is no model
    /// of somebody's that it could be overwriting, and refusing would break every caller that
    /// regenerates a report over yesterday's copy.
    @Test("a workbook composed in code still overwrites freely")
    func composedInCodeIsUnaffected() throws {
        try inTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("report.xlsx")
            try Data("not a workbook".utf8).write(to: url)

            let workbook = Workbook()
            workbook.addSheet(name: "Sheet1").write(1.0, to: "A1")
            try workbook.save(to: url)

            #expect(try Workbook(contentsOf: url).sheets.count == 1)
        }
    }

    // MARK: - The strategy travels with it

    @Test("save(to:) takes a strategy like save() does")
    func carriesTheStrategy() throws {
        try inTemporaryDirectory { directory in
            let source = directory.appendingPathComponent("model.xlsx")
            try package().write(to: source)
            let destination = directory.appendingPathComponent("rebuilt.xlsx")

            try Workbook(contentsOf: source).save(to: destination, strategy: .generated)
            let written = try ZIPReader.read(from: try Data(contentsOf: destination))
            #expect(written.contains { $0.path == "xl/styles.xml" },
                    "a generated archive carries the parts this library writes")
        }
    }
}
