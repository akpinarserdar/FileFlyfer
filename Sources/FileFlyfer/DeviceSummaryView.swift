import SwiftUI

struct DeviceSummaryView: View {
    let device: AndroidDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.gen3")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(device.manufacturer ?? "Android")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            info("Android", value: device.androidVersion.map { "\($0) (API \(device.sdkVersion ?? "—"))" })
            info("Güvenlik", value: device.securityPatch)
            info("Build", value: device.buildID)
            info("Cihaz kodu", value: device.deviceName)
            if let lineage = device.lineageVersion, !lineage.isEmpty {
                info("Sistem", value: lineage)
            }
            if let total = device.storageTotalBytes, let free = device.storageFreeBytes {
                let used = max(0, total - free)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Depolama").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)) boş")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(used), total: Double(total))
                        .tint(.accentColor)
                }
            }
            if let level = device.batteryLevel {
                HStack {
                    Image(systemName: device.batteryCharging == true ? "battery.100.bolt" : "battery.100")
                        .foregroundStyle(level <= 20 ? .red : .secondary)
                    Text("Pil %\(level)").font(.caption)
                    if device.batteryCharging == true { Text("Şarj oluyor").font(.caption2).foregroundStyle(.secondary) }
                }
            }

            Text("Seri: \(maskedSerial)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func info(_ label: LocalizedStringKey, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(value).font(.caption).lineLimit(1).truncationMode(.middle)
            }
        }
    }

    private var maskedSerial: String {
        guard device.serial.count > 6 else { return device.serial }
        return String(device.serial.prefix(3)) + "••••" + String(device.serial.suffix(3))
    }
}
