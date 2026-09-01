import Foundation

/// Parses an OOXML worksheet (`xl/worksheets/sheetN.xml`) into a ``Worksheet``.
///
/// Handles cell values (number, text via shared strings, boolean, error, formula),
/// layout features (freeze panes, column widths, row heights, auto-filter,
/// merged cells), and data validations (list, decimal, integer).
final class WorksheetParser: NSObject, XMLParserDelegate {
    private weak var sheet: Worksheet?
    private let sharedStrings: [String]
    private let styles: ParsedStyleSheet

    // MARK: - Cell parsing state

    private var currentCellRef = ""
    private var currentCellType: String?
    private var currentCellStyleIndex = 0
    private var currentValue = ""
    private var currentFormula = ""
    private var inValue = false
    private var inFormula = false
    private var inCell = false

    // MARK: - Shared formula state

    /// A shared formula's text lives only on its group's master cell, keyed by `si`.
    private var sharedFormulaMasters: [Int: (origin: CellRef, ast: FormulaAST)] = [:]

    /// Group members met before their master. Resolved once the document ends.
    private var pendingSharedCells: [(reference: String, index: Int,
                                      cached: CellValue?, style: CellStyle)] = []

    private var currentFormulaType: String?
    private var currentSharedIndex: Int?

    /// A data table's span and input cells, from the `<f t="dataTable">` attributes.
    private var currentDataTable: (span: String, inputs: [CellRef])?

    // MARK: - Row state

    private var currentRow = 0

    // MARK: - Data validation state

    private var currentValidationSqref = ""
    private var currentValidationType = ""
    private var currentValidationFormula1 = ""
    private var currentValidationFormula2 = ""
    private var inFormula1 = false
    private var inFormula2 = false
    private var inDataValidation = false

    // MARK: - Public API

    /// Parses worksheet XML data, populating the given ``Worksheet``.
    ///
    /// - Parameters:
    ///   - data: The raw XML data for this worksheet.
    ///   - sheet: The worksheet to populate.
    ///   - sharedStrings: The shared strings table for resolving text cells.
    ///   - styles: The parsed style sheet for resolving cell styles.
    static func parse(data: Data, into sheet: Worksheet,
                      sharedStrings: [String], styles: ParsedStyleSheet) throws {
        let handler = WorksheetParser(sheet: sheet, sharedStrings: sharedStrings, styles: styles)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = handler
        guard parser.parse() else {
            throw XLSXReadError.xmlParseError(
                part: "worksheet",
                description: parser.parserError?.localizedDescription ?? "Unknown error")
        }
    }

    private init(sheet: Worksheet, sharedStrings: [String], styles: ParsedStyleSheet) {
        self.sheet = sheet
        self.sharedStrings = sharedStrings
        self.styles = styles
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {

        // Freeze panes
        case "pane":
            if attributeDict["state"] == "frozen",
               let topLeft = attributeDict["topLeftCell"] {
                sheet?.freezePanes(at: topLeft)
            }

        // Column widths
        case "col":
            if let minStr = attributeDict["min"], let min = Int(minStr),
               let maxStr = attributeDict["max"], let max = Int(maxStr),
               let widthStr = attributeDict["width"], let width = Double(widthStr) {
                for col in min...max {
                    sheet?.setColumnWidth(columnIndex: col, width: width)
                }
            }

        // Row
        case "row":
            if let rStr = attributeDict["r"], let row = Int(rStr) {
                currentRow = row
                if let htStr = attributeDict["ht"], let height = Double(htStr) {
                    sheet?.setRowHeight(row: row, height: height)
                }
            }

        // Cell
        case "c":
            inCell = true
            currentCellRef = attributeDict["r"] ?? ""
            currentCellType = attributeDict["t"]
            currentCellStyleIndex = Int(attributeDict["s"] ?? "0") ?? 0
            currentValue = ""
            currentFormula = ""
            currentFormulaType = nil
            currentSharedIndex = nil
            currentDataTable = nil

        // Value element inside cell
        case "v" where inCell:
            inValue = true
            currentValue = ""

        // Formula element inside cell
        case "f" where inCell:
            inFormula = true
            currentFormula = ""
            currentFormulaType = attributeDict["t"]
            currentSharedIndex = attributeDict["si"].flatMap { Int($0) }
            if attributeDict["t"] == "dataTable" {
                let inputs = ["r1", "r2"].compactMap { attributeDict[$0] }.map { CellRef($0) }
                currentDataTable = (span: attributeDict["ref"] ?? "", inputs: inputs)
            }

        // Auto-filter
        case "autoFilter":
            if let ref = attributeDict["ref"] {
                sheet?.setAutoFilter(CellRange(ref))
            }

        // Merge cells
        case "mergeCell":
            if let ref = attributeDict["ref"] {
                sheet?.mergeCells(CellRange(ref))
            }

        // Data validation
        case "dataValidation":
            inDataValidation = true
            currentValidationSqref = attributeDict["sqref"] ?? ""
            currentValidationType = attributeDict["type"] ?? ""
            currentValidationFormula1 = ""
            currentValidationFormula2 = ""

        case "formula1" where inDataValidation:
            inFormula1 = true
            currentValidationFormula1 = ""

        case "formula2" where inDataValidation:
            inFormula2 = true
            currentValidationFormula2 = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue {
            currentValue += string
        } else if inFormula {
            currentFormula += string
        } else if inFormula1 {
            currentValidationFormula1 += string
        } else if inFormula2 {
            currentValidationFormula2 += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {

        case "v" where inCell:
            inValue = false

        case "f" where inCell:
            inFormula = false

        case "c":
            commitCell()
            inCell = false

        case "formula1" where inDataValidation:
            inFormula1 = false

        case "formula2" where inDataValidation:
            inFormula2 = false

        case "dataValidation":
            commitValidation()
            inDataValidation = false

        default:
            break
        }
    }

    // MARK: - Shared Formula Resolution

    func parserDidEndDocument(_ parser: XMLParser) {
        for cell in pendingSharedCells {
            let target = CellRef(cell.reference)
            let ast: FormulaAST
            if let master = sharedFormulaMasters[cell.index] {
                ast = derive(from: master, at: target)
            } else {
                // No master anywhere in the sheet: the group is unresolvable. Say so
                // rather than letting the cell pose as data, matching the `_RAW`
                // convention used for a formula that will not parse.
                ast = .function("_SHARED", [.number(Double(cell.index))])
            }
            sheet?.setCell(
                cell.reference, value: .formula(ast, cached: cell.cached), style: cell.style)
        }
        pendingSharedCells.removeAll()
    }

    /// Shifts a group master's formula onto one of its member cells.
    private func derive(
        from master: (origin: CellRef, ast: FormulaAST), at target: CellRef
    ) -> FormulaAST {
        SharedFormula.translate(
            master.ast,
            rowDelta: target.row - master.origin.row,
            columnDelta: target.column - master.origin.column
        )
    }

    // MARK: - Cell Commit

    /// Resolves the current cell state into a ``CellValue`` and writes it to the sheet.
    private func commitCell() {
        guard !currentCellRef.isEmpty else { return }

        let style = styles.resolve(styleIndex: currentCellStyleIndex)

        // Formula cell
        if !currentFormula.isEmpty {
            let ast: FormulaAST
            // silent: fallback to _RAW wrapper on parse failure is intentional
            if let parsed = try? FormulaParser.parse(currentFormula) {
                ast = parsed
            } else {
                ast = .function("_RAW", [.text(currentFormula)])
            }
            if currentFormulaType == "shared", let index = currentSharedIndex {
                sharedFormulaMasters[index] = (CellRef(currentCellRef), ast)
            }
            let cached = parseCachedValue()
            sheet?.setCell(currentCellRef, value: .formula(ast, cached: cached), style: style)
            return
        }

        // A What-If data table. Excel writes the whole table as one self-closing
        // formula element naming its span and the input cells it varies, with no
        // formula text — so it fails exactly as a shared-formula member does, and
        // the table would otherwise read as a grid of unexplained constants.
        if let table = currentDataTable {
            let arguments: [FormulaAST] = [.text(table.span)] + table.inputs.map { .cellRef($0) }
            sheet?.setCell(
                currentCellRef,
                value: .formula(.function("_DATATABLE", arguments), cached: parseCachedValue()),
                style: style
            )
            return
        }

        // A shared-formula group member. Its `<f>` element is empty: the formula
        // belongs to the group's master and has to be shifted onto this cell. It
        // is still a formula cell, so it must never fall through to the cached
        // value below — that would turn a computed cell into a constant silently.
        if currentFormulaType == "shared", let index = currentSharedIndex {
            let cached = parseCachedValue()
            if let master = sharedFormulaMasters[index] {
                sheet?.setCell(
                    currentCellRef,
                    value: .formula(
                        derive(from: master, at: CellRef(currentCellRef)), cached: cached),
                    style: style
                )
            } else {
                // The master follows this cell in document order. Hold it and
                // resolve when the sheet is fully read.
                pendingSharedCells.append(
                    (reference: currentCellRef, index: index, cached: cached, style: style))
            }
            return
        }

        // Determine cell value from type attribute
        let cellValue: CellValue?

        switch currentCellType {
        case "s":
            // Shared string reference
            if let index = Int(currentValue) {
                if index >= 0, index < sharedStrings.count {
                    cellValue = .text(sharedStrings[index])
                } else {
                    // Out of range: use empty string
                    cellValue = .text("")
                }
            } else {
                cellValue = nil
            }

        case "b":
            // Boolean
            cellValue = .bool(currentValue == "1")

        case "e":
            // Error
            if let error = ExcelError(rawValue: currentValue) {
                cellValue = .error(error)
            } else {
                cellValue = .error(.value)
            }

        default:
            // Number (no type attribute) or empty
            if !currentValue.isEmpty {
                if let number = Double(currentValue) {
                    cellValue = .number(number)
                } else {
                    cellValue = .text(currentValue)
                }
            } else if currentCellStyleIndex > 0 {
                // Empty cell with a style — record as blank
                cellValue = .blank
            } else {
                cellValue = nil
            }
        }

        if let value = cellValue {
            sheet?.setCell(currentCellRef, value: value, style: style)
        }
    }

    /// Parses the cached value from a formula cell's `<v>` element.
    private func parseCachedValue() -> CellValue? {
        guard !currentValue.isEmpty else { return nil }
        if let number = Double(currentValue) {
            return .number(number)
        }
        return .text(currentValue)
    }

    // MARK: - Validation Commit

    /// Resolves the current data validation state and registers it on the sheet.
    private func commitValidation() {
        guard !currentValidationSqref.isEmpty else { return }
        let range = CellRange(currentValidationSqref)

        switch currentValidationType {
        case "list":
            let items = parseListFormula(currentValidationFormula1)
            sheet?.addValidation(range, type: .list(items))

        case "decimal":
            let min = Double(currentValidationFormula1) ?? 0
            let max = Double(currentValidationFormula2) ?? 0
            sheet?.addValidation(range, type: .decimal(min: min, max: max))

        case "whole":
            let min = Int(currentValidationFormula1) ?? 0
            let max = Int(currentValidationFormula2) ?? 0
            sheet?.addValidation(range, type: .integer(min: min, max: max))

        default:
            break
        }
    }

    /// Parses a list validation formula like `"Yes,No,Maybe"` into individual items.
    ///
    /// The OOXML format wraps list items in double quotes; this method strips
    /// those quotes and splits by comma.
    private func parseListFormula(_ formula: String) -> [String] {
        var trimmed = formula.trimmingCharacters(in: .whitespaces)
        // Remove surrounding quotes
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            trimmed = String(trimmed.dropFirst().dropLast())
        }
        return trimmed.split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
