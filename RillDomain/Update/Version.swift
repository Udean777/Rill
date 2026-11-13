import Foundation

/// Dotted numeric semantic version used to compare app releases.
public struct Version: Comparable, Hashable, LosslessStringConvertible, CustomStringConvertible, Sendable {
    public let components: [Int]
    public let rawString: String

    /// Parses a version string such as `"1.2.3"` or `"v1.2.3-beta"`.
    public init(_ string: String) {
        self.rawString = string
        let cleaned = string.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        self.components = cleaned.split(separator: ".")
            .compactMap { $0.prefix(while: \.isNumber) }
            .compactMap { Int($0) }
    }

    public var description: String { rawString }

    public static func == (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return false }
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        var trimmed = components
        while trimmed.last == 0 {
            trimmed.removeLast()
        }
        hasher.combine(trimmed)
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left < right { return true }
            if left > right { return false }
        }
        return false
    }

    /// Compares dotted numeric versions. Non-numeric suffixes (`1.2.3-beta`) are
    /// truncated and missing components count as zero (`1.2` == `1.2.0`).
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        Version(candidate) > Version(current)
    }
}
