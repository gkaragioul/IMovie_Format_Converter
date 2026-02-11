import AppKit
import SwiftUI
import VideoConverterCore

private enum QueueStatus {
    case pending
    case converting
    case completed
    case failed

    var label: String {
        switch self {
        case .pending:
            return "Pending"
        case .converting:
            return "Converting"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        }
    }

    var tint: Color {
        switch self {
        case .pending:
            return .secondary
        case .converting:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

private struct QueueItem: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var destinationURL: URL?
    var status: QueueStatus = .pending
    var progress: Double = 0
    var errorMessage: String?

    var fileName: String {
        sourceURL.lastPathComponent
    }
}

@MainActor
private final class ConverterViewModel: ObservableObject {
    @Published var queue: [QueueItem] = []
    @Published var outputDirectory: URL?
    @Published var overallProgress: Double = 0
    @Published var isConverting = false
    @Published var statusText = "Drop videos here or use Select Media."
    @Published var isDropTargeted = false

    private let engine = ConversionEngine()
    private var conversionTask: Task<Void, Never>?
    private let validExtensions: Set<String> = [
        "3gp", "avi", "m2ts", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "mts", "mxf", "ts", "vob", "webm", "wmv"
    ]

    init() {
        outputDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    var canConvert: Bool {
        !isConverting && !queue.isEmpty && outputDirectory != nil
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Set Export Folder"

        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }

    func pickMediaFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add to Queue"

        if panel.runModal() == .OK {
            addMedia(urls: panel.urls)
        }
    }

    func clearQueue() {
        guard !isConverting else { return }
        queue.removeAll()
        overallProgress = 0
        statusText = "Queue cleared."
    }

    func addMedia(urls: [URL]) {
        guard !isConverting else {
            statusText = "Wait for the current conversion to finish before adding more files."
            return
        }

        let expanded = expandInput(urls)
        guard !expanded.isEmpty else {
            statusText = "No supported video files were found in the dropped items."
            return
        }

        var knownPaths = Set(queue.map { $0.sourceURL.resolvingSymlinksInPath().path })
        var addedCount = 0

        for url in expanded {
            let standardized = url.resolvingSymlinksInPath().path
            guard !knownPaths.contains(standardized) else { continue }
            knownPaths.insert(standardized)
            queue.append(QueueItem(sourceURL: url))
            addedCount += 1
        }

        if addedCount == 0 {
            statusText = "All selected files are already queued."
        } else {
            statusText = "Added \(addedCount) file\(addedCount == 1 ? "" : "s") to queue."
        }
    }

    func startConversion() {
        guard canConvert, let outputDirectory else { return }
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            statusText = "Could not create export folder: \(error.localizedDescription)"
            return
        }

        isConverting = true
        overallProgress = 0
        statusText = "Starting conversion..."

        conversionTask = Task {
            await runQueue(outputDirectory: outputDirectory)
        }
    }

    func cancelConversion() {
        guard isConverting else { return }
        conversionTask?.cancel()
        statusText = "Canceling current conversion..."
    }

    private func runQueue(outputDirectory: URL) async {
        let totalCount = queue.count
        var completedCount = 0

        for itemID in queue.map(\.id) {
            if Task.isCancelled {
                statusText = "Conversion canceled."
                break
            }

            guard let index = queue.firstIndex(where: { $0.id == itemID }) else { continue }

            queue[index].status = .converting
            queue[index].progress = 0
            queue[index].errorMessage = nil

            let inputURL = queue[index].sourceURL
            let outputURL = engine.makeOutputURL(for: inputURL, outputDirectory: outputDirectory)
            queue[index].destinationURL = outputURL

            statusText = "Converting \(inputURL.lastPathComponent)..."
            let completedBeforeCurrent = completedCount

            do {
                try await engine.convert(inputURL: inputURL, outputURL: outputURL) { [weak self] value in
                    Task { @MainActor in
                        guard let self,
                              let activeIndex = self.queue.firstIndex(where: { $0.id == itemID }) else { return }
                        self.queue[activeIndex].progress = value
                        self.overallProgress = (Double(completedBeforeCurrent) + value) / Double(totalCount)
                    }
                }

                guard let finishedIndex = queue.firstIndex(where: { $0.id == itemID }) else { continue }
                queue[finishedIndex].status = .completed
                queue[finishedIndex].progress = 1
                completedCount += 1
                overallProgress = Double(completedCount) / Double(totalCount)
            } catch {
                guard let failedIndex = queue.firstIndex(where: { $0.id == itemID }) else { continue }
                queue[failedIndex].status = .failed
                queue[failedIndex].errorMessage = error.localizedDescription
                completedCount += 1
                overallProgress = Double(completedCount) / Double(totalCount)
            }
        }

        isConverting = false
        conversionTask = nil

        let completed = queue.filter { $0.status == .completed }.count
        let failed = queue.filter { $0.status == .failed }.count

        if Task.isCancelled {
            statusText = "Canceled. Completed \(completed) of \(totalCount) file\(totalCount == 1 ? "" : "s")."
            return
        }

        if failed == 0 {
            statusText = "Finished: \(completed) file\(completed == 1 ? "" : "s") converted to iMovie-compatible MOV."
        } else {
            statusText = "Finished with \(failed) failure\(failed == 1 ? "" : "s")."
        }
    }

    private func expandInput(_ urls: [URL]) -> [URL] {
        var collected: [URL] = []
        let fileManager = FileManager.default

        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys) else { continue }

                for case let fileURL as URL in enumerator where isSupportedVideoFile(fileURL) {
                    collected.append(fileURL)
                }
            } else if isSupportedVideoFile(url) {
                collected.append(url)
            }
        }

        return collected
    }

    private func isSupportedVideoFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return validExtensions.contains(ext)
    }
}

private struct QueueRowView: View {
    let item: QueueItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(item.status.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.status.tint)
            }

            ProgressView(value: item.progress)
                .progressViewStyle(.linear)

            if let destinationURL = item.destinationURL {
                Text("Output: \(destinationURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let errorMessage = item.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ContentView: View {
    @StateObject private var viewModel = ConverterViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("iMovie Batch Converter")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Drag videos in, choose an export folder, and convert everything to QuickTime MOV (H.264 + AAC) for iMovie.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text("Export folder:")
                    .fontWeight(.semibold)
                Text(viewModel.outputDirectory?.path ?? "Not set")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.isDropTargeted ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(viewModel.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8]))
                )
                .frame(height: 110)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "film.stack.fill")
                            .font(.system(size: 24, weight: .medium))
                        Text("Drop one or many videos here")
                            .font(.headline)
                        Text("Folders are supported and scanned recursively.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                )
                .dropDestination(for: URL.self) { urls, _ in
                    viewModel.addMedia(urls: urls)
                    return true
                } isTargeted: { targeted in
                    viewModel.isDropTargeted = targeted
                }

            HStack(spacing: 10) {
                Button("Select Media", action: viewModel.pickMediaFiles)
                    .disabled(viewModel.isConverting)
                Button("Set Export Path", action: viewModel.chooseOutputDirectory)
                    .disabled(viewModel.isConverting)
                Button("Clear Queue", action: viewModel.clearQueue)
                    .disabled(viewModel.isConverting || viewModel.queue.isEmpty)

                Spacer()

                if viewModel.isConverting {
                    Button("Cancel", role: .destructive, action: viewModel.cancelConversion)
                }

                Button("Convert", action: viewModel.startConversion)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canConvert)
            }

            Text("Queue (\(viewModel.queue.count))")
                .font(.title3.weight(.semibold))

            List(viewModel.queue) { item in
                QueueRowView(item: item)
            }
            .frame(minHeight: 280)

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: viewModel.overallProgress)
                    .progressViewStyle(.linear)
                Text(viewModel.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 920, minHeight: 680)
    }
}

@main
struct VideoConverterOsxApp: App {
    var body: some Scene {
        WindowGroup("iMovie Batch Converter") {
            ContentView()
        }
        .defaultSize(width: 940, height: 700)
    }
}
