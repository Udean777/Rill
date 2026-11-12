import Foundation

/// Safe, pure Swift arithmetic expression evaluator (see architecture.md §6).
/// Supports addition, subtraction, multiplication, division, modulo, power, and parentheses.
public enum ExpressionEvaluator {
    public enum EvaluationError: Error, Equatable {
        case invalidSyntax
        case divisionByZero
    }

    public static func evaluate(_ expression: String) -> Double? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Must contain at least one arithmetic operator to be considered a calculation,
        // preventing single numbers or plain words from triggering calculation results.
        let operators: Set<Character> = ["+", "-", "*", "/", "%", "^"]
        guard trimmed.contains(where: { operators.contains($0) }) else { return nil }

        var parser = Parser(text: trimmed)
        do {
            let result = try parser.parseExpression()
            guard parser.isAtEnd() else { return nil }
            guard !result.isNaN && !result.isInfinite else { return nil }
            return result
        } catch {
            return nil
        }
    }

    public static func formatResult(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        } else {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.maximumFractionDigits = 8
            formatter.minimumFractionDigits = 0
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
    }
}

private struct Parser {
    private let text: [Character]
    private var index: Int = 0

    init(text: String) {
        self.text = Array(text)
    }

    mutating func isAtEnd() -> Bool {
        skipWhitespace()
        return index >= text.count
    }

    mutating func parseExpression() throws(ExpressionEvaluator.EvaluationError) -> Double {
        var value = try parseTerm()

        while true {
            skipWhitespace()
            guard index < text.count else { break }
            let op = text[index]
            if op == "+" {
                index += 1
                let next = try parseTerm()
                value += next
            } else if op == "-" {
                index += 1
                let next = try parseTerm()
                value -= next
            } else {
                break
            }
        }
        return value
    }

    private mutating func parseTerm() throws(ExpressionEvaluator.EvaluationError) -> Double {
        var value = try parseFactor()

        while true {
            skipWhitespace()
            guard index < text.count else { break }
            let op = text[index]
            if op == "*" {
                index += 1
                let next = try parseFactor()
                value *= next
            } else if op == "/" {
                index += 1
                let next = try parseFactor()
                guard next != 0 else { throw .divisionByZero }
                value /= next
            } else if op == "%" {
                index += 1
                let next = try parseFactor()
                guard next != 0 else { throw .divisionByZero }
                value = value.truncatingRemainder(dividingBy: next)
            } else {
                break
            }
        }
        return value
    }

    private mutating func parseFactor() throws(ExpressionEvaluator.EvaluationError) -> Double {
        skipWhitespace()
        guard index < text.count else { throw .invalidSyntax }

        if text[index] == "+" {
            index += 1
            return try parseFactor()
        } else if text[index] == "-" {
            index += 1
            let value = try parseFactor()
            return -value
        }

        var base: Double
        if text[index] == "(" {
            index += 1
            base = try parseExpression()
            skipWhitespace()
            guard index < text.count, text[index] == ")" else {
                throw .invalidSyntax
            }
            index += 1
        } else {
            base = try parseNumber()
        }

        skipWhitespace()
        if index < text.count, text[index] == "^" {
            index += 1
            let exponent = try parseFactor()
            base = pow(base, exponent)
        }

        return base
    }

    private mutating func parseNumber() throws(ExpressionEvaluator.EvaluationError) -> Double {
        skipWhitespace()
        let start = index
        var hasDecimal = false

        while index < text.count {
            let char = text[index]
            if char.isNumber {
                index += 1
            } else if char == "." && !hasDecimal {
                hasDecimal = true
                index += 1
            } else {
                break
            }
        }

        guard index > start else { throw .invalidSyntax }
        let numberString = String(text[start..<index])
        guard let value = Double(numberString) else { throw .invalidSyntax }
        return value
    }

    private mutating func skipWhitespace() {
        while index < text.count, text[index].isWhitespace {
            index += 1
        }
    }
}
