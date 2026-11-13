import Foundation
import Testing

@testable import RillDomain

@Suite("CurrencyParser")
struct CurrencyParserTests {
    @Test(arguments: [
        ("$20", "20", "USD"),
        ("US$20", "20", "USD"),
        ("C$40", "40", "CAD"),
        ("€50", "50", "EUR"),
        ("£100", "100", "GBP"),
        ("¥1000", "1000", "JPY"),
        ("₹250", "250", "INR"),
        ("Rp 20000", "20000", "IDR"),
        ("rp 20000", "20000", "IDR"),
        ("Rp20000", "20000", "IDR"),
        ("RM 15", "15", "MYR"),
        ("20 USD", "20", "USD"),
        ("50 eur", "50", "EUR"),
        ("1000 JPY", "1000", "JPY"),
        ("IDR 200000", "200000", "IDR"),
        ("1,000 USD", "1000", "USD"),
        ("19.99 EUR", "19.99", "EUR"),
    ])
    func `parses amount and currency`(input: String, amount: String, code: String) {
        let parsed = CurrencyParser.parse(input)
        #expect(parsed?.amount == Decimal(string: amount))
        #expect(parsed?.code == code)
        #expect(parsed?.targetCode == nil)
    }

    @Test(arguments: ["", "   ", "hello", "12 * 4", "safari", "20", "20 ZZZ", "USD"])
    func `returns nil for non-currency input`(input: String) {
        #expect(CurrencyParser.parse(input) == nil)
    }

    @Test func `parses an explicit target after to`() {
        let parsed = CurrencyParser.parse("20 USD to IDR")
        #expect(parsed?.amount == 20)
        #expect(parsed?.code == "USD")
        #expect(parsed?.targetCode == "IDR")
    }

    @Test func `parses an explicit target after in`() {
        let parsed = CurrencyParser.parse("$20 in IDR")
        #expect(parsed?.code == "USD")
        #expect(parsed?.targetCode == "IDR")
    }

    @Test func `rejects an unknown target currency`() {
        #expect(CurrencyParser.parse("20 USD to ZZZ") == nil)
    }
}
