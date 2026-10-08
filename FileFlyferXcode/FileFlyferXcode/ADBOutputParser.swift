import Foundation

enum ADBOutputParser {
    static func devices(_ output: String) -> [AndroidDevice] {
        output.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard fields.count >= 2, !fields[0].hasPrefix("*") else { return nil }
            let state = DeviceState(rawValue: fields[1]) ?? .unknown
            let attributes = Dictionary(uniqueKeysWithValues: fields.dropFirst(2).compactMap { field -> (String, String)? in
                guard let separator = field.firstIndex(of: ":") else { return nil }
                return (String(field[..<separator]), String(field[field.index(after: separator)...]))
            })
            return AndroidDevice(
                serial: fields[0], state: state, product: attributes["product"],
                model: attributes["model"], deviceName: attributes["device"], androidVersion: nil
            )
        }
    }

    static func remoteFiles(_ output: String, parent: String) -> [RemoteFile] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 4,
                  let nameData = Data(base64Encoded: String(fields[0])),
                  let name = String(data: nameData, encoding: .utf8),
                  let size = Int64(fields[2]) else { return nil }
            let timestamp = TimeInterval(fields[3]).map(Date.init(timeIntervalSince1970:))
            let kind = RemoteFile.Kind(rawValue: String(fields[1])) ?? .other
            return RemoteFile(path: NSString(string: parent).appendingPathComponent(name), name: name, kind: kind, size: size, modifiedAt: timestamp)
        }
        .sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
