import SwiftUI

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
                Text("FileFlyfer, telefonunuza ek uygulama kurmadan ADB üzerinden çalışır.").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    instruction(1, "Android telefonda Ayarlar'ı açın.")
                    instruction(2, "Telefon Hakkında bölümüne girin.")
                    instruction(3, "Yapım Numarası'na yedi kez dokunun.")
                    instruction(4, "Geliştirici Seçenekleri'ni açın.")
                    instruction(5, "USB Hata Ayıklama'yı etkinleştirin.")
                    instruction(6, "Telefonu veri aktarımını destekleyen bir USB kabloyla Mac'e bağlayın.")
                    instruction(7, "Telefonda görünen “Bu bilgisayara izin ver” penceresini onaylayın.")
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
                                Text(item.errorMessage ?? statusText(item.status)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }.frame(width: 240, alignment: .leading).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                    }
                }.padding(.horizontal, 10).padding(.bottom, 10)
            }.frame(height: 58)
        }.frame(height: 104)
    }
    @ViewBuilder private func status(_ value: TransferStatus) -> some View {
        if value == .running { ProgressView().controlSize(.small) }
        else { Image(systemName: value == .completed ? "checkmark.circle.fill" : value == .failed ? "xmark.circle.fill" : value == .cancelled ? "stop.circle" : "clock").foregroundStyle(value == .completed ? .green : value == .failed ? .red : .secondary) }
    }
    private func statusText(_ value: TransferStatus) -> String {
        switch value { case .waiting: "Bekliyor"; case .running: "Devam ediyor"; case .completed: "Tamamlandı"; case .failed: "Başarısız"; case .cancelled: "İptal edildi" }
    }
}
