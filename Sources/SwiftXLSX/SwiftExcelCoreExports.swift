// The spreadsheet vocabulary — CellValue, CellRef, FormulaAST, ExcelError and the
// rest — moved to SwiftExcelCore so that a function library and a file reader can
// share it without depending on each other.
//
// Re-exported rather than merely imported so that `import SwiftXLSX` continues to
// see those types. The extraction is meant to be invisible to existing callers;
// making every one of them add a second import would be a breaking change dressed
// up as a refactor.
@_exported import SwiftExcelCore
