import PhotosUI
import SwiftData
import SwiftUI

/// flomo 式速记卡片：文本 + 图片 + 语音 + 保存
@MainActor
struct ComposeCardView: View {
    var todayCount: Int = 0
    var onSaved: (() -> Void)?

    @Environment(MemoStore.self) private var store
    @State private var viewModel = ComposeViewModel()
    @State private var speech = SpeechRecognizer()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var pulse = false
    @State private var showDeniedAlert = false
    @State private var failMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("随手记下灵感，用 #标签 归类", text: $viewModel.content, axis: .vertical)
                .lineLimit(3...8)

            if !viewModel.stagedImages.isEmpty {
                stagedRow
            }

            HStack(spacing: 18) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(1, ComposeViewModel.maxImages - viewModel.stagedImages.count),
                    matching: .images
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .disabled(!viewModel.canAddImages)

                micButton

                Spacer()

                Text("今日 \(todayCount) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                saveButton
            }
        }
        .cardStyle()
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await viewModel.addImages(from: newItems)
                pickerItems = []
            }
        }
        .onChange(of: speech.transcript) { _, transcript in
            viewModel.applyTranscript(transcript)
        }
        .onChange(of: speech.isRecording) { _, recording in
            pulse = recording
        }
        .onChange(of: speech.state) { _, newState in
            switch newState {
            case .denied:
                showDeniedAlert = true
            case .failed(let message):
                failMessage = message
            default:
                break
            }
        }
        .alert("无法使用语音", isPresented: $showDeniedAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在系统设置中允许使用麦克风与语音识别")
        }
        .alert(
            "语音识别失败",
            isPresented: Binding(
                get: { failMessage != nil },
                set: { if !$0 { failMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(failMessage ?? "")
        }
    }

    // MARK: - 子控件

    private var micButton: some View {
        Button {
            if speech.isRecording {
                speech.stop()
            } else {
                Haptics.tap()
                viewModel.beginDictation()
                speech.start()
            }
        } label: {
            ZStack {
                if speech.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .frame(width: 30, height: 30)
                        .scaleEffect(pulse ? 1.4 : 1.0)
                        .opacity(pulse ? 0.15 : 0.9)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "mic")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel(speech.isRecording ? "停止录音" : "语音输入")
    }

    private var saveButton: some View {
        Button {
            speech.stop()
            Haptics.success()
            if viewModel.save(store: store) {
                onSaved?()
            }
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(viewModel.canSave ? Color.accentColor : Color(.tertiaryLabel))
        }
        .disabled(!viewModel.canSave)
        .accessibilityLabel("保存")
    }

    private var stagedRow: some View {        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.stagedImages) { staged in
                    if let preview = staged.preview {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Button {
                                viewModel.removeStaged(staged)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
