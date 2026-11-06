import SwiftData
import SwiftUI

@main
struct InspirationsApp: App {
    private let container: ModelContainer
    @State private var store: MemoStore

    init() {
        do {
            container = try ModelContainer(for: Memo.self, Tag.self, ImageAsset.self)
        } catch {
            fatalError("无法初始化数据库：\(error)")
        }
        _store = State(initialValue: MemoStore(
            modelContext: container.mainContext,
            imageStore: .shared
        ))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
        .modelContainer(container)
    }
}
