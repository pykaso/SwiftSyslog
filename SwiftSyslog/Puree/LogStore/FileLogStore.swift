//
// This file is basen on awesome Puree log agregator
// https://github.com/cookpad/Puree-Swift
//
import Foundation

public protocol FileManagerProtocol {
    func load(from path: URL) -> Data?
    func write(_ data: Data, to path: URL) throws
    func remove(at path: URL) throws
    func removeDirectory(at path: URL) throws
    func createEmptyDirectoryIfNeeded(at path: URL) throws
    func cachesDirectoryURL() throws -> URL
}

struct SystemFileManager: FileManagerProtocol {
    private var fileManager: FileManager {
        return FileManager.default
    }

    public func load(from path: URL) -> Data? {
        return fileManager.contents(atPath: path.path)
    }

    public func write(_ data: Data, to path: URL) throws {
        try data.write(to: path)
    }

    public func remove(at path: URL) throws {
        try fileManager.removeItem(atPath: path.path)
    }

    public func removeDirectory(at path: URL) throws {
        if isExistsDirectory(at: path) {
            try fileManager.removeItem(at: path)
        }
    }

    public func isExistsDirectory(at path: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory)
    }

    public func createEmptyDirectoryIfNeeded(at path: URL) throws {
        if !isExistsDirectory(at: path) {
            try fileManager.createDirectory(atPath: path.path, withIntermediateDirectories: false, attributes: nil)
        }
    }

    public func cachesDirectoryURL() throws -> URL {
        return try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}

public class FileLogStore: LogStore {
    private let directoryName: String
    private var bundle: Bundle = Bundle.main
    private var baseDirectoryURL: URL!

    public init(directoryName: String = "Logs") {
        self.directoryName = directoryName
    }

    private func fileURL(for group: String) -> URL {
        return baseDirectoryURL.appendingPathComponent(group.base16Encoded)
    }

    private var fileManager: FileManagerProtocol = SystemFileManager()

    private func storedLogs(of group: String) -> Set<LogEntry> {
        if let data = fileManager.load(from: fileURL(for: group)) {
            let decorder = PropertyListDecoder()
            if let logs = try? decorder.decode([LogEntry].self, from: data) {
                return Set<LogEntry>(logs)
            }
        }
        return []
    }

    private func write(_ logs: Set<LogEntry>, for group: String) {
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(logs) {
            try? fileManager.write(data, to: fileURL(for: group))
        }
    }

    private func createCachesDirectory() throws {
        try fileManager.createEmptyDirectoryIfNeeded(at: baseDirectoryURL)
    }

    public func prepare() throws {
        let cacheDirectoryURL = try fileManager.cachesDirectoryURL()
        baseDirectoryURL = cacheDirectoryURL.appendingPathComponent(directoryName)
        try createCachesDirectory()
    }

    public func add(_ logs: Set<LogEntry>, for group: String, completion: (() -> Void)?) {
        let unioned = storedLogs(of: group).union(logs)
        write(unioned, for: group)
        completion?()
    }

    public func remove(_ logs: Set<LogEntry>, from group: String, completion: (() -> Void)?) {
        let subtracted = storedLogs(of: group).subtracting(logs)
        write(subtracted, for: group)
        completion?()
    }

    public func retrieveLogs(of group: String, completion: (Set<LogEntry>) -> Void) {
        let logs = storedLogs(of: group)
        completion(logs)
    }

    public func flush() {
        try? fileManager.removeDirectory(at: baseDirectoryURL)
        try? createCachesDirectory()
    }
}

fileprivate extension String {
    var base16Encoded: String {
        data(using: .utf8)!.map { String(format: "%02hhx", $0) }.joined()
    }
}
