import Foundation
import XCTest
@testable import VideoConverterCore

final class ConversionEngineTests: XCTestCase {
    func testParseTimestamp() {
        XCTAssertEqual(ConversionEngine.parseTimestamp("00:00:03.50") ?? -1, 3.5, accuracy: 0.0001)
        XCTAssertEqual(ConversionEngine.parseTimestamp("01:02:03.00") ?? -1, 3723, accuracy: 0.0001)
        XCTAssertNil(ConversionEngine.parseTimestamp("invalid"))
    }

    func testProgressSecondsParsing() {
        XCTAssertEqual(ConversionEngine.progressSeconds(from: "out_time_ms=1500000") ?? -1, 1.5, accuracy: 0.0001)
        XCTAssertEqual(ConversionEngine.progressSeconds(from: "out_time_us=2500000") ?? -1, 2.5, accuracy: 0.0001)
        XCTAssertEqual(ConversionEngine.progressSeconds(from: "out_time=00:00:02.00") ?? -1, 2.0, accuracy: 0.0001)
        XCTAssertNil(ConversionEngine.progressSeconds(from: "progress=continue"))
    }

    func testOutputNameUniqueness() throws {
        let engine = ConversionEngine()
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let inputURL = tempDirectory.appendingPathComponent("clip.mp4")
        FileManager.default.createFile(atPath: inputURL.path, contents: Data(), attributes: nil)

        let first = engine.makeOutputURL(for: inputURL, outputDirectory: tempDirectory)
        XCTAssertEqual(first.lastPathComponent, "clip_imovie.mov")

        FileManager.default.createFile(atPath: first.path, contents: Data(), attributes: nil)

        let second = engine.makeOutputURL(for: inputURL, outputDirectory: tempDirectory)
        XCTAssertEqual(second.lastPathComponent, "clip_imovie_1.mov")
    }

    func testIntegrationConversionProducesMov() async throws {
        let engine = ConversionEngine()
        guard let ffmpegURL = engine.locateFFmpeg() else {
            throw XCTSkip("ffmpeg is not available in this environment")
        }

        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let inputURL = tempDirectory.appendingPathComponent("input.mp4")
        let outputURL = tempDirectory.appendingPathComponent("output.mov")

        let generateArgs = [
            "-hide_banner",
            "-loglevel", "error",
            "-y",
            "-f", "lavfi",
            "-i", "testsrc=size=320x180:rate=24",
            "-f", "lavfi",
            "-i", "sine=frequency=1000:sample_rate=48000",
            "-t", "1.2",
            "-c:v", "mpeg4",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            inputURL.path
        ]

        try runShellProcess(executableURL: ffmpegURL, arguments: generateArgs)

        let progressFlag = ThreadSafeFlag()
        try await engine.convert(inputURL: inputURL, outputURL: outputURL) { value in
            if value > 0 {
                progressFlag.setTrue()
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let size = attrs[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(size, 0)
        XCTAssertTrue(progressFlag.value)
    }

    private func runShellProcess(executableURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            XCTFail("Process failed with status \(process.terminationStatus): \(stderr)")
        }
    }
}

private final class ThreadSafeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func setTrue() {
        lock.lock()
        storage = true
        lock.unlock()
    }
}
