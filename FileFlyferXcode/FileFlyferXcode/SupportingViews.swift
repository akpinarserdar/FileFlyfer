import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

struct WirelessConnectionView: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pairingAddress = ""
    @State private var pairingCode = ""
    @State private var deviceAddress = ""
    @State private var qrServiceName = "studio-" + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))
    @State private var qrSecret = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
    @State private var wirelessTask: Task<Void, Never>?

    private var validEndpoint: (String) -> Bool {
        { value in
            let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty, let port = Int(parts[1]) else { return false }
            return (1...65535).contains(port) && !parts[0].contains(where: \.isWhitespace)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Kablosuz Android bağlantısı", systemImage: "wifi")
                        .font(.title2.bold())
                    Text("Telefon ve Mac aynı Wi-Fi ağına bağlı olmalıdır.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Kapat") { dismiss() }.keyboardShortcut(.cancelAction)
            }

            GroupBox("İlk kez eşleştir") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Android 11+ telefonda Kablosuz hata ayıklama → QR kodla cihaz eşleştir bölümünü açıp bu kodu okutun.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        if let qrImage {
                            Image(nsImage: qrImage).interpolation(.none).resizable().frame(width: 150, height: 150)
                                .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Kare kodu telefonun kendi kamerasıyla değil, Kablosuz hata ayıklama içindeki QR eşleştirme ekranıyla okutun.", systemImage: "info.circle")
                                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            if model.isQRWirelessActionRunning {
                                Button(role: .cancel) {
                                    wirelessTask?.cancel()
                                } label: {
                                    Label("İptal", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                            } else if model.isWirelessActionRunning {
                                ProgressView("Bağlantı işlemi sürüyor…").controlSize(.small)
                            } else {
                                Button {
                                    wirelessTask = Task {
                                        await model.pairAndConnectWirelessQR(serviceName: String(qrServiceName), secret: qrSecret)
                                        wirelessTask = nil
                                    }
                                } label: { Label("Taranınca otomatik bağlan", systemImage: "wifi") }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    Divider()
                    Text("İsterseniz eşleştirme koduyla da bağlanabilirsiniz.")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Telefonda Geliştirici seçenekleri → Kablosuz hata ayıklama → Eşleştirme koduyla eşleştir bölümünü açın.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        TextField("Eşleştirme adresi · ör. 192.168.1.25:37000", text: $pairingAddress)
                            .textFieldStyle(.roundedBorder)
                        TextField("6 haneli kod", text: $pairingCode)
                            .textFieldStyle(.roundedBorder).frame(width: 125)
                            .onChange(of: pairingCode) { value in
                                pairingCode = String(value.filter(\.isNumber).prefix(6))
                            }
                    }
                    Button {
                        Task { await model.pairWireless(address: pairingAddress, pairingCode: pairingCode) }
                    } label: {
                        if model.isWirelessActionRunning { ProgressView().controlSize(.small) }
                        else { Label("Eşleştir", systemImage: "checkmark.shield") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isWirelessActionRunning || !validEndpoint(pairingAddress) || pairingCode.count != 6)
                }.padding(.vertical, 4)
            }

            GroupBox("Cihaza bağlan") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Eşleştirmeden sonra Kablosuz hata ayıklama ana ekranındaki IP adresi ve bağlantı noktası farklı olabilir. Bu adresi kullanın.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        TextField("Cihaz adresi · ör. 192.168.1.25:42000", text: $deviceAddress)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            Task { await model.connectWireless(address: deviceAddress) }
                        } label: { Label("Bağlan", systemImage: "wifi") }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isWirelessActionRunning || !validEndpoint(deviceAddress))
                    }
                    if let device = model.selectedDevice, device.serial.contains(":"), device.state == .device {
                        Button(role: .destructive) {
                            Task { await model.disconnectWireless(address: device.serial) }
                        } label: { Label("Seçili kablosuz cihazın bağlantısını kes", systemImage: "wifi.slash") }
                            .disabled(model.isWirelessActionRunning)
                    }
                }.padding(.vertical, 4)
            }

            if !model.recentWirelessConnections.isEmpty {
                GroupBox("Son bağlanan cihazlar") {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(model.recentWirelessConnections) { connection in
                                HStack(spacing: 10) {
                                    Image(systemName: "wifi").foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(connection.deviceName).lineLimit(1)
                                        Text("\(connection.endpoint) · \(connection.lastConnectedAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 4)
                                    Button {
                                        deviceAddress = connection.endpoint
                                        Task { await model.connectWireless(address: connection.endpoint, deviceSerial: connection.deviceSerial) }
                                    } label: {
                                        Label("Yeniden bağlan", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(model.isWirelessActionRunning)
                                    Button {
                                        model.forgetRecentWirelessConnection(connection)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Geçmişten kaldır")
                                    .disabled(model.isWirelessActionRunning)
                                }
                                if connection.id != model.recentWirelessConnections.last?.id { Divider() }
                            }
                        }.padding(.vertical, 4)
                    }
                    .frame(maxHeight: 190)
                }
            }

            if let message = model.wirelessMessage {
                Label(message, systemImage: message.localizedCaseInsensitiveContains("tamam") || message.localizedCaseInsensitiveContains("kuruldu") ? "checkmark.circle" : "info.circle")
                    .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .padding(24)
        .frame(width: 620)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: model.wirelessConnectionSucceeded) { succeeded in
            if succeeded { dismiss() }
        }
        .onDisappear { wirelessTask?.cancel() }
    }

    private var qrImage: NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("WIFI:T:ADB;S:\(qrServiceName);P:\(qrSecret);;".utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 256, height: 256))
    }
}

struct PathNavigatorView: View {
    let path: String
    let goUp: () -> Void
    let navigate: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: goUp) {
                Image(systemName: "arrow.up")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(isAtRoot)
            .help("Üst klasöre dön")

            Image(systemName: "internaldrive")
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(parts.indices, id: \.self) { index in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            Button(parts[index].title) { navigate(parts[index].path) }
                                .buttonStyle(.plain)
                                .fontWeight(index == parts.indices.last ? .semibold : .regular)
                                .foregroundStyle(index == parts.indices.last ? .primary : .secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(index == parts.indices.last ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                .id(parts[index].path)
                                .help(parts[index].path)
                        }
                    }
                }
                .onAppear { scrollToCurrent(using: proxy) }
                .onChange(of: path) { _ in scrollToCurrent(using: proxy) }
            }

            Text(path)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: 240, alignment: .trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.035))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Geçerli konum: \(path)")
    }

    private var isAtRoot: Bool { path == "/sdcard" || path == "/storage/emulated/0" }

    private func scrollToCurrent(using proxy: ScrollViewProxy) {
        guard let current = parts.last?.path else { return }
        DispatchQueue.main.async { proxy.scrollTo(current, anchor: .trailing) }
    }

    private var parts: [(title: String, path: String)] {
        let root = path.hasPrefix("/storage/emulated/0") ? "/storage/emulated/0" : "/sdcard"
        var result = [(String(localized: "Dahili Depolama"), root)]
        let remainder = path.dropFirst(root.count).split(separator: "/").map(String.init)
        var current = root
        for component in remainder { current += "/" + component; result.append((component, current)) }
        return result
    }
}

struct OnboardingView: View {
    let refresh: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Android cihazınızı bağlayın", systemImage: "cable.connector").font(.title2.bold())
                Text("FileFlyfer, telefonunuza ek uygulama kurmadan ADB üzerinden çalışır. USB veya kablosuz bağlantı kullanabilirsiniz.").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    instruction(1, "Android telefonda Ayarlar'ı açın.")
                    instruction(2, "Telefon Hakkında bölümüne girin.")
                    instruction(3, "Yapım Numarası'na yedi kez dokunun.")
                    instruction(4, "Geliştirici Seçenekleri'ni açın.")
                    instruction(5, "USB Hata Ayıklama'yı etkinleştirin.")
                    instruction(6, "Telefonu veri aktarımını destekleyen bir USB kabloyla Mac'e bağlayın.")
                    instruction(7, "Telefonda görünen “Bu bilgisayara izin ver” penceresini onaylayın.")
                }
                GroupBox("Kablosuz bağlanma") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Android 11 veya sonrası: Geliştirici Seçenekleri → Kablosuz hata ayıklama'yı açın, ardından üstteki Kablosuz Bağlan düğmesinden QR kodu okutun.")
                            .fixedSize(horizontal: false, vertical: true)
                        Label("Telefon ve Mac aynı Wi-Fi ağına bağlı olmalı.", systemImage: "wifi")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                GroupBox("Bağlantı sorunu mu var?") {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Kablo yalnızca şarj destekliyor olabilir.", systemImage: "exclamationmark.triangle")
                        Label("Telefonun ekran kilidi açık olmalıdır.", systemImage: "lock.open")
                        Label("RSA izin penceresi telefonda bekliyor olabilir.", systemImage: "checkmark.shield")
                        Label("USB bağlantı modunu veya kabloyu değiştirmeyi deneyin.", systemImage: "cable.connector")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                Button(action: refresh) { Label("Tekrar Kontrol Et", systemImage: "arrow.clockwise") }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: 640, alignment: .leading).padding(40)
        }
    }
    private func instruction(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top) {
            Text("\(number)").font(.caption.bold()).frame(width: 24, height: 24).background(.tint, in: Circle()).foregroundStyle(.white)
            Text(text).padding(.top, 2)
        }
    }
}

struct DeviceProblemView: View {
    let device: AndroidDevice
    let refresh: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: device.state == .unauthorized ? "lock.trianglebadge.exclamationmark" : "wifi.exclamationmark")
                .font(.system(size: 42)).foregroundStyle(.secondary)
            Text(device.state.title).font(.title2.bold())
            Text(device.state == .unauthorized ? "Telefonun kilidini açın ve RSA izin penceresinde “İzin ver” seçeneğine dokunun." : "USB kablosunu çıkarıp yeniden takın ve telefon ekranının açık olduğunu doğrulayın.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 500)
            Button("Tekrar Kontrol Et", action: refresh).buttonStyle(.borderedProminent)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlaceholderView: View {
    let title: LocalizedStringKey
    let icon: String
    let detail: LocalizedStringKey
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(title).font(.title3.bold())
            Text(detail).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TransferQueueView: View {
    @ObservedObject var model: AppViewModel
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Aktarımlar").font(.headline); Spacer(); Button("İptal", action: model.cancelTransfer).disabled(!model.transfers.contains { $0.status == .running }) }.padding(10)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(model.transfers) { item in
                        HStack(spacing: 8) {
                            status(item.status)
                            VStack(alignment: .leading) {
                                Text(item.fileName).lineLimit(1)
                                Label(item.deviceName, systemImage: item.deviceID.contains(":") || item.deviceID.contains("_adb-tls-connect._tcp") ? "wifi" : "cable.connector")
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                Text(item.errorMessage ?? statusText(item.status)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }.frame(maxHeight: .infinity, alignment: .center)
                        }.frame(width: 260, alignment: .leading).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                    }
                }.padding(.horizontal, 10).padding(.bottom, 10)
            }.frame(height: 72)
        }.frame(height: 118)
    }
    @ViewBuilder private func status(_ value: TransferStatus) -> some View {
        if value == .running { ProgressView().controlSize(.small) }
        else { Image(systemName: value == .completed ? "checkmark.circle.fill" : value == .failed ? "xmark.circle.fill" : value == .cancelled ? "stop.circle" : "clock").foregroundStyle(value == .completed ? .green : value == .failed ? .red : .secondary) }
    }
    private func statusText(_ value: TransferStatus) -> String {
        switch value { case .waiting: "Bekliyor"; case .running: "Devam ediyor"; case .completed: "Tamamlandı"; case .failed: "Başarısız"; case .cancelled: "İptal edildi" }
    }
}
