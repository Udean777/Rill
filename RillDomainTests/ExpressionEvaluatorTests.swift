import Foundation
import RillDomain
import Testing

@Suite("ExpressionEvaluator")
struct ExpressionEvaluatorTests {
    @Test func `basic arithmetic evaluation`() {
        #expect(ExpressionEvaluator.evaluate("2 + 2") == 4.0)
        #expect(ExpressionEvaluator.evaluate("10 - 3") == 7.0)
        #expect(ExpressionEvaluator.evaluate("6 * 7") == 42.0)
        #expect(ExpressionEvaluator.evaluate("15 / 3") == 5.0)
        #expect(ExpressionEvaluator.evaluate("10 % 4") == 2.0)
        #expect(ExpressionEvaluator.evaluate("2 ^ 3") == 8.0)
    }

    @Test func `precedence and parentheses`() {
        #expect(ExpressionEvaluator.evaluate("2 + 3 * 4") == 14.0)
        #expect(ExpressionEvaluator.evaluate("(2 + 3) * 4") == 20.0)
        #expect(ExpressionEvaluator.evaluate("2 * (3 + 4 * 2)") == 22.0)
    }

    @Test func `decimals and negative numbers`() {
        #expect(ExpressionEvaluator.evaluate("3.5 * 2") == 7.0)
        #expect(ExpressionEvaluator.evaluate("-5 + 12") == 7.0)
        #expect(ExpressionEvaluator.evaluate("-(3 + 2)") == -5.0)
    }

    @Test func `invalid syntax or division by zero returns nil`() {
        #expect(ExpressionEvaluator.evaluate("hello world") == nil)
        #expect(ExpressionEvaluator.evaluate("42") == nil)
        #expect(ExpressionEvaluator.evaluate("10 / 0") == nil)
        #expect(ExpressionEvaluator.evaluate("2 + * 3") == nil)
        #expect(ExpressionEvaluator.evaluate("(2 + 3") == nil)
    }

    @Test func `formatting integers and decimals`() {
        #expect(ExpressionEvaluator.formatResult(42.0) == "42")
        #expect(ExpressionEvaluator.formatResult(4000.0) == "4,000")
        #expect(ExpressionEvaluator.formatResult(3.14159) == "3.14159")
    }

    @Test func `natural operators equals sign and thousands separators`() {
        #expect(ExpressionEvaluator.evaluate("12 × 5") == 60.0)
        #expect(ExpressionEvaluator.evaluate("20 ÷ 4") == 5.0)
        #expect(ExpressionEvaluator.evaluate("6 x 7") == 42.0)
        #expect(ExpressionEvaluator.evaluate("= 10 + 20") == 30.0)
        #expect(ExpressionEvaluator.evaluate("10 + 20 =") == 30.0)
        #expect(ExpressionEvaluator.evaluate("1,000 + 2,500") == 3500.0)
    }
}
