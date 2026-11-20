import SwiftUI

private enum Palette {
    static let background = Color(red: 0.025, green: 0.05, blue: 0.09)
    static let accent = Color(red: 0.37, green: 0.92, blue: 0.84)
    static let secondary = Color(red: 0.54, green: 0.67, blue: 0.76)
    static let card = Color(red: 0.065, green: 0.105, blue: 0.16)
}

struct RecorderView: View {
    @StateObject private var recorder = SessionController()
    @Environment(\.scenePhase) private var phase
    @State private var deletionTarget: URL?
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 23) {
                        heading
                        purpose
                        recordingCard
                        diagnostics
                        savedSessions
                        privacyFootnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: phase) { newPhase in
                if newPhase != .active { recorder.handleAppInactive() }
                if newPhase == .active { recorder.refreshFiles() }
            }
            .alert("記録エラー", isPresented: Binding(
                get: { recorder.errorText != nil },
                set: { if !$0 { recorder.errorText = nil } })) {
                    Button("閉じる") { recorder.errorText = nil }
                } message: { Text(recorder.errorText ?? "") }
            .confirmationDialog("保存済みの記録を削除しますか？",
                isPresented: Binding(
                    get: { deletionTarget != nil },
                    set: { if !$0 { deletionTarget = nil } }),
                titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    if let target = deletionTarget { recorder.delete(target) }
                    deletionTarget = nil
                }
                Button("キャンセル", role: .cancel) { deletionTarget = nil }
            } message: {
                Text("アプリ内の記録を削除します。すでに他の場所へ共有したコピーは削除されません。")
            }
            .sheet(isPresented: $showPrivacy) { privacySheet }
        }
    }

    private var heading: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SIGNAL ECHOES").font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(2.5).foregroundStyle(.white)
                Text("FIELD RECORDER · M1").font(.system(size: 10, weight: .medium))
                    .tracking(2).foregroundStyle(Palette.accent)
            }
            Spacer()
            Image(systemName: "waveform.path")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Palette.accent)
        }
    }
    private var purpose: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("見えない気配を、記録する。")
                .font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
            Text("Bluetooth信号の強弱と、自分自身の移動の変化を短時間だけ記録します。記録後はJSONとして書き出し、3Dビューアで再生できます。")
                .font(.system(size: 13)).lineSpacing(5).foregroundStyle(Palette.secondary)
        }
    }
    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Circle()
                    .fill(recorder.isRecording ? Palette.accent : Palette.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(recorder.isRecording ? "RECORDING / 記録中" : "READY / 待機中")
                    .font(.system(size: 11, weight: .bold)).tracking(1.5)
                    .foregroundStyle(recorder.isRecording ? Palette.accent : Palette.secondary)
                Spacer()
                Text("FOREGROUND ONLY")
                    .font(.system(size: 9, weight: .medium)).tracking(1)
                    .foregroundStyle(Palette.secondary)
            }
            Text(String(format: "%02d:%02d", recorder.durationSeconds / 60, recorder.durationSeconds % 60))
                .font(.system(size: 60, weight: .light, design: .monospaced))
                .foregroundStyle(.white).monospacedDigit()
            ProgressView(value: Double(recorder.durationSeconds), total: 900)
                .tint(Palette.accent)
            HStack(spacing: 10) {
                metric("受信コールバック", value: "\(recorder.receivedSamples)")
                metric("最新ビン内の信号", value: "\(recorder.visibleSignals)")
            }
            Button {
                recorder.isRecording ? recorder.stop() : recorder.start()
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                    Text(recorder.isRecording ? "記録を終了する" : "記録を開始する")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .foregroundStyle(recorder.isRecording ? .white : Palette.background)
                .background(recorder.isRecording ? Color(red: 0.55, green: 0.2, blue: 0.24) : Palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text(recorder.statusLabel).font(.system(size: 11))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("初回のアクセス許可で記録が中断された場合は、許可後にもう一度開始してください。")
                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }
        .padding(22)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.accent.opacity(0.15)))
    }
    private func metric(_ name: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(name).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            Text(value).font(.system(size: 25, weight: .medium, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CAPTURE STATUS").font(.system(size: 10, weight: .semibold))
                .tracking(2).foregroundStyle(Palette.accent)
            statusRow("Bluetooth", value: recorder.bluetoothLabel)
            statusRow("自分の位置", value: recorder.positionLabel)
            statusRow("記録上限", value: "15分 / 50MiB")
            statusRow("記録方法", value: "前景のみ・クラウド送信なし")
        }
        .padding(18)
        .background(Palette.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
    }
    private func statusRow(_ key: String, value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(Palette.secondary)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(.white).multilineTextAlignment(.trailing)
        }.font(.system(size: 12))
    }
    private var savedSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECORDED SESSIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2).foregroundStyle(Palette.accent)
                Spacer()
                Text("\(recorder.recentSessions.count)件")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            if recorder.recentSessions.isEmpty {
                Text("まだ記録はありません。記録を終了するとここに表示されます。")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(recorder.recentSessions, id: \.path) { url in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "doc.text").foregroundStyle(Palette.accent)
                        Text("記録 " + String(url.lastPathComponent.prefix(8)))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("JSON").font(.system(size: 10))
                            .foregroundStyle(Palette.secondary)
                    }
                    HStack(spacing: 12) {
                        Button("共有ファイルを準備") { recorder.prepareShare(url) }
                            .font(.system(size: 11)).buttonStyle(.bordered)
                        Button("削除", role: .destructive) { deletionTarget = url }
                            .font(.system(size: 11)).buttonStyle(.bordered)
                    }
                }
                .padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            }
            if let url = recorder.shareURL {
                ShareLink(item: url) {
                    Label("ファイルへ保存・共有", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity).padding(12)
                }
                .foregroundStyle(Palette.background)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 12))
                Text("共有先のコピーはアプリの24時間削除対象外です。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }
    }
    private var privacyFootnote: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                Text("光点は人物位置や人数を示しません。BLEのRSSIから方向や距離は確定できません。")
            }.font(.system(size: 11)).lineSpacing(3).foregroundStyle(Palette.secondary)
            Button("保存期間とプライバシーについて") { showPrivacy = true }
                .font(.system(size: 11)).foregroundStyle(Palette.accent)
        }.padding(.bottom, 22)
    }
    private var privacySheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("計測と保存について").font(.title2.bold())
                Text("観測できたBluetooth信号を、受信強度の変化として記録します。すべての人や機器を検出できるわけではありません。")
                Text("機器UUID、広告内容、端末名、緯度経度はエクスポートしません。端末内で短時間だけ利用する仮IDと相対座標も、第三者の行動に関する情報を含み得ます。")
                Text("収集は画面が表示されている間だけです。画面を離れると記録を中断します。記録は原則24時間後の次回起動時に削除し、手動でも削除できます。共有済みのコピーは自動削除されません。")
                Text("データをGitHub、SNS、公開サイトにアップロードしないでください。").fontWeight(.semibold)
                Spacer()
            }.font(.system(size: 14)).lineSpacing(5)
                .padding(22).navigationTitle("プライバシー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { showPrivacy = false }
                }}
        }
    }
}