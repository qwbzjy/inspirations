import SwiftUI

/// 轻量 toast 提示（顶部浮现，1.4s 后消失）
struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    Text(message)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(1.4))
                            withAnimation(.easeOut(duration: 0.25)) {
                                if self.message == message {
                                    self.message = nil
                                }
                            }
                        }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
