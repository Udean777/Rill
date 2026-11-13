import Foundation
import RillDomain
import Testing

@Suite("Update")
struct UpdateTests {
    @Test func `version comparison handles patch, multi-digit, prerelease, and leading v`() {
        #expect(Version.isNewer("1.2.3", than: "1.2.2"))
        #expect(Version.isNewer("1.10.0", than: "1.9.9"))
        #expect(!Version.isNewer("1.2", than: "1.2.0"))
        #expect(Version.isNewer("2.0.0-beta", than: "1.9.0"))
        #expect(Version.isNewer("v1.3.0", than: "1.2.9"))
    }

    @Test func `version comparable and hashable normalize trailing zeros`() {
        #expect(Version("1.2.3") > Version("1.2.2"))
        #expect(Version("1.2") == Version("1.2.0"))
        #expect(Version("2.0.0-beta") > Version("1.9.0"))
        #expect(Version("v1.3.0") == Version("1.3.0"))
        #expect(Set([Version("1.2"), Version("1.2.0")]).count == 1)
    }

    @Test func `progress step advances only on whole percent boundary`() {
        #expect(UpdateInstallerSupport.progressStepAdvanced(from: nil, to: 0.05))
        #expect(!UpdateInstallerSupport.progressStepAdvanced(from: 0.121, to: 0.129))
        #expect(UpdateInstallerSupport.progressStepAdvanced(from: 0.129, to: 0.131))
    }

    @Test func `download byte limit caps excessive payloads`() {
        #expect(UpdateInstallerSupport.downloadByteLimit(expectedBytes: 15_000_000) == 15_000_000)
        #expect(
            UpdateInstallerSupport.downloadByteLimit(expectedBytes: 500_000_000)
                == UpdateInstallerSupport.downloadCeilingBytes
        )
    }

    @Test func `download usability validates status and size`() {
        #expect(
            UpdateInstallerSupport.downloadIsUsable(
                status: 200,
                receivedBytes: 15_000_000,
                expectedBytes: 15_000_000
            )
        )
        #expect(
            !UpdateInstallerSupport.downloadIsUsable(
                status: 404,
                receivedBytes: 15_000_000,
                expectedBytes: 15_000_000
            )
        )
    }

    @Test func `shellSingleQuoted escapes embedded single quotes`() {
        #expect(UpdateInstallerSupport.shellSingleQuoted("test'app") == "'test'\\''app'")
    }

    @Test func `runsFromImmutableLocation detects app translocation and read-only volumes`() {
        #expect(
            UpdateInstallerSupport.runsFromImmutableLocation(
                appPath: "/AppTranslocation/d/app.app",
                volumeIsReadOnly: { _ in false }
            )
        )
        #expect(
            !UpdateInstallerSupport.runsFromImmutableLocation(
                appPath: "/Applications/Rill.app",
                volumeIsReadOnly: { _ in false }
            )
        )
    }

    @Test func `installScript targets Rill bundle identifier`() {
        let script = UpdateInstallerSupport.installScript(
            appPath: "/Applications/Rill.app",
            dmgPath: "/tmp/Rill.dmg"
        )
        #expect(script.contains("com.ssajudn.Rill"))
        #expect(script.contains("hdiutil attach"))
    }
}
