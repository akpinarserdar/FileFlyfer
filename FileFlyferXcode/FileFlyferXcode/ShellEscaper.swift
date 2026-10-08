import Foundation

enum ShellEscaper {
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func isAllowedSharedStoragePath(_ path: String) -> Bool {
        let normalized = NSString(string: path).standardizingPath
        let roots = ["/sdcard", "/storage/emulated/0"]
        return roots.contains { normalized == $0 || normalized.hasPrefix($0 + "/") }
    }

    static func join(_ parent: String, _ child: String) throws -> String {
        guard !child.contains("/"), child != ".", child != "..", !child.isEmpty else {
            throw AppError.unsafePath
        }
        let result = NSString(string: parent).appendingPathComponent(child)
        guard isAllowedSharedStoragePath(result) else { throw AppError.unsafePath }
        return result
    }
}
