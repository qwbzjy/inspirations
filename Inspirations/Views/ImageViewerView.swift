import SwiftData
import SwiftUI

/// 全屏图片查看器：翻页 + 捏合缩放 + 双击缩放

@MainActor
struct ImageViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let assets: [ImageAsset]
    @State var index: Int

    @Environment(MemoStore.self) private var store

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(assets.enumerated()), id: \.element.id) { pair in
                    ZoomableImage(image: store.imageStore.fullImage(for: pair.element))
                        .tag(pair.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
        }
        .overlay(alignment: .bottom) {
            if assets.count > 1 {
                Text("\(index + 1) / \(assets.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 24)
            }
        }
    }
}

/// 单页图片：捏合缩放、双击复位

@MainActor
struct ZoomableImage: View {
    let image: UIImage?
    @State private var scale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { proxy in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(scale * gestureScale)
                    .gesture(
                        MagnificationGesture()
                            .updating($gestureScale) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                let target = max(1, min(4, scale * value))
                                withAnimation(.spring(duration: 0.25)) {
                                    scale = target < 1.15 ? 1 : target
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.25)) {
                            scale = scale > 1 ? 1 : 2
                        }
                    }
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}
