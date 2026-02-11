import Foundation

public enum ConversionError: LocalizedError {
    case ffmpegMissing
    case ffprobeMissing
    case inputFileMissing(URL)
    case processLaunchFailed(String)
    case conversionFailed(exitCode: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .ffmpegMissing:
            return "ffmpeg was not found. Install it with Homebrew (brew install ffmpeg) or bundle ffmpeg inside the app resources."
        case .ffprobeMissing:
            return "ffprobe was not found. Install it with Homebrew (brew install ffmpeg) or bundle ffprobe inside the app resources."
        case .inputFileMissing(let url):
            return "Input file is missing: \(url.path)"
        case .processLaunchFailed(let reason):
            return "Failed to launch conversion process: \(reason)"
        case .conversionFailed(_, let message):
            if message.isEmpty {
                return "ffmpeg conversion failed."
            }
            return "ffmpeg conversion failed: \(message)"
        }
    }
}

public final class ConversionEngine {
    public init() {}

    public func locateFFmpeg() -> URL? {
        locateBinary(named: "ffmpeg")
    }

    public func locateFFprobe() -> URL? {
        locateBinary(named: "ffprobe")
    }

    public func makeOutputURL(for inputURL: URL, outputDirectory: URL) -> URL {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let preferredName = "\(baseName)_imovie.mov"
        let preferredURL = outputDirectory.appendingPathComponent(preferredName)
        if !FileManager.default.fileExists(atPath: preferredURL.path) {
            return preferredURL
        }

        var index = 1
        while true {
            let candidate = outputDirectory.appendingPathComponent("\(baseName)_imovie_\(index).mov")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    public func probeDuration(for inputURL: URL) async throws -> Double {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ConversionError.inputFileMissing(inputURL)
        }
        guard let ffprobeURL = locateFFprobe() else {
            throw ConversionError.ffprobeMissing
        }

        let arguments = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            inputURL.path
        ]

        let (status, stdout, stderr) = runProcessSync(executableURL: ffprobeURL, arguments: arguments)
        guard status == 0 else {
            throw ConversionError.conversionFailed(exitCode: status, message: stderr)
        }

        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let duration = Double(trimmed), duration.isFinite, duration > 0 else {
            throw ConversionError.conversionFailed(exitCode: status, message: "Unable to parse media duration from ffprobe output.")
        }
        return duration
    }

    public func convert(
        inputURL: URL,
        outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ConversionError.inputFileMissing(inputURL)
        }
        guard let ffmpegURL = locateFFmpeg() else {
            throw ConversionError.ffmpegMissing
        }

        let duration: Double
        do {
            duration = try await probeDuration(for: inputURL)
        } catch {
            duration = 0
        }

        let arguments = [
            "-hide_banner",
            "-loglevel", "error",
            "-y",
            "-i", inputURL.path,
            "-map", "0:v:0?",
            "-map", "0:a:0?",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-profile:v", "high",
            "-level", "4.1",
            "-movflags", "+faststart",
            "-c:a", "aac",
            "-b:a", "192k",
            "-ac", "2",
            "-progress", "pipe:1",
            "-nostats",
            outputURL.path
        ]

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let progressTask = Task.detached(priority: .userInitiated) {
            do {
                for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
                    if let seconds = Self.progressSeconds(from: String(line)), duration > 0 {
                        let clamped = min(max(seconds / duration, 0), 1)
                        progress(clamped)
                        continue
                    }
                    if line == "progress=end" {
                        progress(1)
                    }
                }
            } catch {
                // Ignore stream interruption; conversion status is handled by process exit code.
            }
        }

        let status = try await withTaskCancellationHandler {
            try await Self.runProcessAsync(process)
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }

        _ = await progressTask.result

        let stderrData = try? stderrPipe.fileHandleForReading.readToEnd()
        let stderr = String(data: stderrData ?? Data(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard status == 0 else {
            throw ConversionError.conversionFailed(exitCode: status, message: stderr)
        }

        progress(1)
    }

    public static func progressSeconds(from line: String) -> Double? {
        if let value = line.split(separator: "=", maxSplits: 1).last,
           line.hasPrefix("out_time_ms="),
           let raw = Double(value) {
            return raw / 1_000_000
        }

        if let value = line.split(separator: "=", maxSplits: 1).last,
           line.hasPrefix("out_time_us="),
           let raw = Double(value) {
            return raw / 1_000_000
        }

        if let value = line.split(separator: "=", maxSplits: 1).last,
           line.hasPrefix("out_time=") {
            return parseTimestamp(String(value))
        }

        return nil
    }

    public static func parseTimestamp(_ value: String) -> Double? {
        let comps = value.split(separator: ":")
        guard comps.count == 3,
              let hours = Double(comps[0]),
              let minutes = Double(comps[1]),
              let seconds = Double(comps[2]) else {
            return nil
        }
        return (hours * 3600) + (minutes * 60) + seconds
    }

    private func locateBinary(named name: String) -> URL? {
        let bundledURL = Bundle.main.url(forResource: name, withExtension: nil)
        if let bundledURL, FileManager.default.isExecutableFile(atPath: bundledURL.path) {
            return bundledURL
        }

        let fileManager = FileManager.default
        let commonPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]

        for path in commonPaths where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let whichURL = URL(fileURLWithPath: "/usr/bin/which")
        guard fileManager.isExecutableFile(atPath: whichURL.path) else {
            return nil
        }

        let (status, stdout, _) = runProcessSync(executableURL: whichURL, arguments: [name])
        guard status == 0 else {
            return nil
        }

        let resolvedPath = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedPath.isEmpty, fileManager.isExecutableFile(atPath: resolvedPath) else {
            return nil
        }

        return URL(fileURLWithPath: resolvedPath)
    }

    private static func runProcessAsync(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { runningProcess in
                continuation.resume(returning: runningProcess.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ConversionError.processLaunchFailed(error.localizedDescription))
            }
        }
    }

    private func runProcessSync(executableURL: URL, arguments: [String]) -> (Int32, String, String) {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return (1, "", error.localizedDescription)
        }

        process.waitUntilExit()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: outputData, encoding: .utf8) ?? ""
        let stderr = String(data: errorData, encoding: .utf8) ?? ""

        return (process.terminationStatus, stdout, stderr)
    }
}
