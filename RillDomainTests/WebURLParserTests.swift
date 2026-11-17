import Foundation
import RillDomain
import Testing

@Suite("WebURLParser")
struct WebURLParserTests {
    @Test func `parses explicit http and https urls`() {
        #expect(WebURLParser.parse("https://apple.com")?.absoluteString == "https://apple.com")
        #expect(WebURLParser.parse("http://example.com/path?a=1")?.absoluteString == "http://example.com/path?a=1")
    }

    @Test func `parses bare domains and paths as https`() {
        #expect(WebURLParser.parse("github.com")?.absoluteString == "https://github.com")
        #expect(WebURLParser.parse("docs.swift.org/swift-book")?.absoluteString == "https://docs.swift.org/swift-book")
    }

    @Test func `parses localhost and ipv4 addresses as http`() {
        #expect(WebURLParser.parse("localhost:3000")?.absoluteString == "http://localhost:3000")
        #expect(WebURLParser.parse("127.0.0.1:8080/api")?.absoluteString == "http://127.0.0.1:8080/api")
    }

    @Test func `ignores non-url queries paths and math`() {
        #expect(WebURLParser.parse("open settings") == nil)
        #expect(WebURLParser.parse("10 + 20") == nil)
        #expect(WebURLParser.parse("3.14") == nil)
        #expect(WebURLParser.parse("/Users/test/file.txt") == nil)
        #expect(WebURLParser.parse("~/Documents") == nil)
    }
}
