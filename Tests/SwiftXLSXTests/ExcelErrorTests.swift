import Testing
@testable import SwiftXLSX

@Suite("ExcelError Tests")
struct ExcelErrorTests {

    // MARK: - Raw Value Strings

    @Test("All 7 cases have correct rawValue strings")
    func rawValues() {
        #expect(ExcelError.value.rawValue == "#VALUE!")
        #expect(ExcelError.ref.rawValue == "#REF!")
        #expect(ExcelError.div0.rawValue == "#DIV/0!")
        #expect(ExcelError.name.rawValue == "#NAME?")
        #expect(ExcelError.null.rawValue == "#NULL!")
        #expect(ExcelError.num.rawValue == "#NUM!")
        #expect(ExcelError.na.rawValue == "#N/A")
    }

    // MARK: - CustomStringConvertible

    @Test("description returns the rawValue")
    func descriptionMatchesRawValue() {
        #expect(ExcelError.value.description == "#VALUE!")
        #expect(ExcelError.ref.description == "#REF!")
        #expect(ExcelError.div0.description == "#DIV/0!")
        #expect(ExcelError.name.description == "#NAME?")
        #expect(ExcelError.null.description == "#NULL!")
        #expect(ExcelError.num.description == "#NUM!")
        #expect(ExcelError.na.description == "#N/A")
    }

    // MARK: - Equatable

    @Test("Same cases are equal")
    func equalCases() {
        #expect(ExcelError.value == ExcelError.value)
        #expect(ExcelError.ref == ExcelError.ref)
        #expect(ExcelError.div0 == ExcelError.div0)
        #expect(ExcelError.name == ExcelError.name)
        #expect(ExcelError.null == ExcelError.null)
        #expect(ExcelError.num == ExcelError.num)
        #expect(ExcelError.na == ExcelError.na)
    }

    @Test("Different cases are not equal")
    func unequalCases() {
        #expect(ExcelError.value != ExcelError.ref)
        #expect(ExcelError.div0 != ExcelError.name)
        #expect(ExcelError.null != ExcelError.num)
        #expect(ExcelError.na != ExcelError.value)
    }

    // MARK: - Init from rawValue

    @Test("Can initialize from rawValue string")
    func initFromRawValue() {
        #expect(ExcelError(rawValue: "#VALUE!") == .value)
        #expect(ExcelError(rawValue: "#REF!") == .ref)
        #expect(ExcelError(rawValue: "#DIV/0!") == .div0)
        #expect(ExcelError(rawValue: "#NAME?") == .name)
        #expect(ExcelError(rawValue: "#NULL!") == .null)
        #expect(ExcelError(rawValue: "#NUM!") == .num)
        #expect(ExcelError(rawValue: "#N/A") == .na)
    }

    @Test("Invalid rawValue returns nil")
    func invalidRawValue() {
        #expect(ExcelError(rawValue: "#INVALID!") == nil)
        #expect(ExcelError(rawValue: "") == nil)
        #expect(ExcelError(rawValue: "VALUE") == nil)
    }

    // MARK: - Hashable

    @Test("Can be used in a Set")
    func hashable() {
        let errors: Set<ExcelError> = [.value, .ref, .div0, .name, .null, .num, .na]
        #expect(errors.count == 7)
        #expect(errors.contains(.value))
        #expect(errors.contains(.na))
    }
}
