import Foundation

/// Calls back when the config file changes. Watches the directory too, because many editors save
/// by writing a new file and renaming it over the old one, which a watch on the file alone misses.
@MainActor
final class ConfigWatcher {
    private let directory: URL
    private let file: URL
    private let onChange: @MainActor () -> Void
    private var directorySource: (any DispatchSourceFileSystemObject)?
    private var fileSource: (any DispatchSourceFileSystemObject)?
    private var pending: DispatchWorkItem?

    init(file: URL, onChange: @escaping @MainActor () -> Void) {
        self.file = file
        self.directory = file.deletingLastPathComponent()
        self.onChange = onChange
        directorySource = watch(directory, events: .write)
        watchFile()
    }

    private func watchFile() {
        fileSource?.cancel()
        fileSource = watch(file, events: [.write, .extend, .delete, .rename])
    }

    private func watch(_ url: URL, events: DispatchSource.FileSystemEvent) -> (any DispatchSourceFileSystemObject)? {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.changed() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }

    /// Editors often write in several steps, so wait for them to settle.
    private func changed() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                // The file may have been replaced; watch the new one.
                self.watchFile()
                self.onChange()
            }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}
