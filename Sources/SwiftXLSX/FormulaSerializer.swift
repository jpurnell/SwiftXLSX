/// Converts a ``FormulaAST`` into an Excel formula string.
public enum FormulaSerializer {

    // MARK: - Public API

    /// Serializes the given AST node into a formula string (without leading `=`).
    public static func serialize(_ ast: FormulaAST) -> String {
        serializeNode(ast)
    }

    // MARK: - Precedence

    private static func precedence(of ast: FormulaAST) -> Int {
        switch ast {
        case .equal, .notEqual, .greaterThan, .lessThan, .greaterOrEqual, .lessOrEqual:
            return 1
        case .concatenate:
            return 2
        case .add, .subtract:
            return 3
        case .multiply, .divide:
            return 4
        case .power:
            return 5
        case .negate:
            return 6
        case .function, .cellRef, .cellRange, .sheetRef, .namedRange,
             .number, .text, .bool, .error:
            return 7
        }
    }

    // MARK: - Serialization

    private static func serializeNode(_ ast: FormulaAST) -> String {
        switch ast {
        case .cellRef(let ref):
            return ref.reference
        case .cellRange(let range):
            return range.reference
        case .sheetRef(let sheetRef):
            return sheetRef.reference
        case .namedRange(let name):
            return name
        case .number(let n):
            return formatNumber(n)
        case .text(let s):
            return "\"\(s)\""
        case .bool(let b):
            return b ? "TRUE" : "FALSE"
        case .error(let e):
            return e.rawValue

        case .add(let left, let right):
            return serializeBinary(ast, left, "+", right, rightAssociative: false)
        case .subtract(let left, let right):
            return serializeBinary(ast, left, "-", right, rightAssociative: true)
        case .multiply(let left, let right):
            return serializeBinary(ast, left, "*", right, rightAssociative: false)
        case .divide(let left, let right):
            return serializeBinary(ast, left, "/", right, rightAssociative: true)
        case .power(let left, let right):
            return serializeBinary(ast, left, "^", right, rightAssociative: false)
        case .concatenate(let left, let right):
            return serializeBinary(ast, left, "&", right, rightAssociative: false)

        case .negate(let expr):
            return serializeNegate(expr)

        case .equal(let left, let right):
            return serializeBinary(ast, left, "=", right, rightAssociative: false)
        case .notEqual(let left, let right):
            return serializeBinary(ast, left, "<>", right, rightAssociative: false)
        case .greaterThan(let left, let right):
            return serializeBinary(ast, left, ">", right, rightAssociative: false)
        case .lessThan(let left, let right):
            return serializeBinary(ast, left, "<", right, rightAssociative: false)
        case .greaterOrEqual(let left, let right):
            return serializeBinary(ast, left, ">=", right, rightAssociative: false)
        case .lessOrEqual(let left, let right):
            return serializeBinary(ast, left, "<=", right, rightAssociative: false)

        case .function(let name, let args):
            let argStrings = args.map { serializeNode($0) }
            return "\(name)(\(argStrings.joined(separator: ",")))"
        }
    }

    private static func serializeBinary(
        _ parent: FormulaAST,
        _ left: FormulaAST,
        _ op: String,
        _ right: FormulaAST,
        rightAssociative: Bool
    ) -> String {
        let parentPrec = precedence(of: parent)
        let leftStr = parenthesizeChild(left, parentPrecedence: parentPrec, isRightChild: false, rightAssociative: false)
        let rightStr = parenthesizeChild(right, parentPrecedence: parentPrec, isRightChild: true, rightAssociative: rightAssociative)
        return "\(leftStr)\(op)\(rightStr)"
    }

    private static func parenthesizeChild(
        _ child: FormulaAST,
        parentPrecedence: Int,
        isRightChild: Bool,
        rightAssociative: Bool
    ) -> String {
        let childPrec = precedence(of: child)
        let needsParens: Bool
        if childPrec < parentPrecedence {
            needsParens = true
        } else if isRightChild && rightAssociative && childPrec == parentPrecedence {
            needsParens = true
        } else {
            needsParens = false
        }

        let serialized = serializeNode(child)
        return needsParens ? "(\(serialized))" : serialized
    }

    private static func serializeNegate(_ expr: FormulaAST) -> String {
        let exprPrec = precedence(of: expr)
        let serialized = serializeNode(expr)
        if exprPrec < precedence(of: .negate(expr)) {
            return "-(\(serialized))"
        }
        return "-\(serialized)"
    }

    private static func formatNumber(_ n: Double) -> String {
        if n == n.rounded(.towardZero) && !n.isNaN && !n.isInfinite {
            if n.truncatingRemainder(dividingBy: 1) == 0 {
                return String(Int(n))
            }
        }
        return String(n)
    }
}
