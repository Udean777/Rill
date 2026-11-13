import AppKit
import Foundation
import RillDomain

extension UpdateManager {
    /// Downloads the release DMG with bounded size limits and installs it in-place.
    public func downloadAndInstallUpdate() {
        guard let url = dmgDownloadURL ?? releaseNotesURL else { return }

        guard url.pathExtension.lowercased() == "dmg" else {
            NSWorkspace.shared.open(url)
            return
        }

        if UpdateInstallerSupport.runsFromImmutableLocation(
            appPath: Bundle.main.bundlePath,
            volumeIsReadOnly: { path in
                (try? URL(fileURLWithPath: path)
                    .resourceValues(forKeys: [.volumeIsReadOnlyKey])
                    .volumeIsReadOnly) ?? false
            }
        ) {
            showAlert(
                title: String(localized: "Move Rill to Applications"),
                message: String(localized: "Rill is running from a read-only or translocated location. Move it to /Applications to use in-app updates.")
            )
            return
        }

        guard !isDownloading else { return }
        let targetVersion = availableVersion ?? ""
        isDownloading = true
        downloadProgress = nil
        state = .downloading(progress: nil)

        let expectedBytes = downloadExpectedBytes
        let byteLimit = UpdateInstallerSupport.downloadByteLimit(expectedBytes: expectedBytes)

        let delegate: BoundedUpdateDownloadDelegate
        do {
            delegate = try BoundedUpdateDownloadDelegate(
                byteLimit: byteLimit,
                progress: { [weak self] received, total in
                    guard let self else { return }
                    let expected = expectedBytes ?? total
                    guard let expected, expected > 0 else { return }
                    let fraction = min(Double(received) / Double(expected), 1.0)
                    if UpdateInstallerSupport.progressStepAdvanced(from: self.downloadProgress, to: fraction) {
                        self.downloadProgress = fraction
                        self.state = .downloading(progress: fraction)
                    }
                },
                completion: { [weak self] tempURL, response, error in
                    guard let self else { return }
                    self.downloadSession?.finishTasksAndInvalidate()
                    self.downloadSession = nil
                    self.isDownloading = false

                    guard let tempURL, error == nil else {
                        let message = error?.localizedDescription
                            ?? String(localized: "Failed to download the update.")
                        self.state = .failed(message)
                        self.showAlert(
                            title: String(localized: "Download Failed"),
                            message: message
                        )
                        return
                    }

                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let received =
                        (try? FileManager.default.attributesOfItem(atPath: tempURL.path))
                        .flatMap { $0[.size] as? NSNumber }?.int64Value ?? 0

                    guard UpdateInstallerSupport.downloadIsUsable(
                        status: status,
                        receivedBytes: received,
                        expectedBytes: expectedBytes
                    ) else {
                        try? FileManager.default.removeItem(at: tempURL)
                        self.state = .failed(String(localized: "Invalid download payload (HTTP \(status))."))
                        self.showAlert(
                            title: String(localized: "Download Failed"),
                            message: String(localized: "Invalid download payload.")
                        )
                        return
                    }

                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent("Rill-update-\(UUID().uuidString).dmg")
                    do {
                        try? FileManager.default.removeItem(at: destination)
                        try FileManager.default.moveItem(at: tempURL, to: destination)
                    } catch {
                        self.state = .failed(error.localizedDescription)
                        self.showAlert(
                            title: String(localized: "Download Failed"),
                            message: error.localizedDescription
                        )
                        return
                    }

                    self.state = .installing
                    Task {
                        await self.performBackgroundInstall(dmgPath: destination.path, targetVersion: targetVersion)
                    }
                }
            )
        } catch {
            isDownloading = false
            state = .failed(error.localizedDescription)
            showAlert(
                title: String(localized: "Download Failed"),
                message: error.localizedDescription
            )
            return
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        downloadSession = session
        session.dataTask(with: url).resume()
    }
}

@MainActor
final class BoundedUpdateDownloadDelegate: NSObject, URLSessionDataDelegate {
    private let byteLimit: Int64
    private let progress: @MainActor (Int64, Int64?) -> Void
    private let completion: @MainActor (URL?, URLResponse?, Error?) -> Void
    private let fileURL: URL
    private let fileHandle: FileHandle
    private var response: URLResponse?
    private var responseExpectedBytes: Int64?
    private var receivedBytes: Int64 = 0
    private var completed = false
    private var exceededLimit = false
    private var writeError: Error?

    init(
        byteLimit: Int64,
        progress: @escaping @MainActor (Int64, Int64?) -> Void,
        completion: @escaping @MainActor (URL?, URLResponse?, Error?) -> Void
    ) throws {
        self.byteLimit = byteLimit
        self.progress = progress
        self.completion = completion
        let temporaryFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Rill-update-\(UUID().uuidString).download")
        self.fileURL = temporaryFileURL
        guard FileManager.default.createFile(atPath: temporaryFileURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            self.fileHandle = try FileHandle(forWritingTo: temporaryFileURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryFileURL)
            throw error
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        MainActor.assumeIsolated {
            self.response = response
            self.responseExpectedBytes = response.expectedContentLength > 0
                ? response.expectedContentLength
                : nil
        }
        completionHandler(.allow)
    }

    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        MainActor.assumeIsolated {
            guard self.writeError == nil, !self.exceededLimit else { return }
            let chunkBytes = Int64(data.count)
            guard chunkBytes <= self.byteLimit - self.receivedBytes else {
                self.exceededLimit = true
                dataTask.cancel()
                return
            }
            do {
                try self.fileHandle.write(contentsOf: data)
                self.receivedBytes += chunkBytes
                self.progress(self.receivedBytes, self.responseExpectedBytes)
            } catch {
                self.writeError = error
                dataTask.cancel()
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        MainActor.assumeIsolated {
            let closeError: Error?
            do {
                try self.fileHandle.close()
                closeError = nil
            } catch {
                closeError = error
            }
            if let writeError = self.writeError {
                self.complete(location: nil, response: self.response, error: writeError)
            } else if self.exceededLimit {
                self.complete(location: nil, response: self.response, error: POSIXError(.EFBIG))
            } else if let error {
                self.complete(location: nil, response: self.response, error: error)
            } else if let closeError {
                self.complete(location: nil, response: self.response, error: closeError)
            } else {
                self.complete(location: self.fileURL, response: self.response, error: nil)
            }
        }
    }

    @MainActor
    private func complete(location: URL?, response: URLResponse?, error: Error?) {
        guard !completed else { return }
        completed = true
        if location == nil {
            try? FileManager.default.removeItem(at: fileURL)
        }
        completion(location, response, error)
    }
}
