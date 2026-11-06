import SwiftData
import SwiftUI

/// 共享灵感列表：置顶速记卡 + 搜索 + 日分组

@MainActor
struct MemoListView: View {
    let filter: MemoFilter
    var onOpenSidebar: (() -> Void)?

    @Query(sort: \Memo.createdAt, order: .reverse) private var allMemos: [Memo]
    @State private var searchText = ""
    @State private var toastMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ComposeCardView(
                todayCount: allMemos.filter { Calendar.current.isDateInToday($0.createdAt) }.count,
                onSaved: { showToast("已保存") }
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
            Divider()
                .padding(.top, 8)
            memoList
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(filter.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索灵感")
        .toolbar {
            if onOpenSidebar != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onOpenSidebar?()
                    } label: {
                        Label("标签", systemImage: "tag")
                    }
                }
            }
        }
        .navigationDestination(for: Memo.self) { memo in
            MemoDetailView(memo: memo)
        }
        .toast($toastMessage)
    }

    // MARK: - 过滤与分组

    private var filtered: [Memo] {
        var result = allMemos
        switch filter {
        case .all:
            break
        case .untagged:
            result = result.filter { $0.tags.isEmpty }
        case .tag(let path):
            // 命中标签自身或其子标签
            result = result.filter { memo in
                memo.tags.contains { $0.path == path || $0.path.hasPrefix(path + "/") }
            }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.content.localizedStandardContains(searchText) }
        }
        return result
    }

    private var sections: [(date: Date, label: String, memos: [Memo])] {
        let grouped = Dictionary(grouping: filtered) { DateGrouper.startOfDay(for: $0.createdAt) }
        return grouped.keys
            .sorted(by: >)
            .map { day in
                let memos = (grouped[day] ?? []).sorted { $0.createdAt > $1.createdAt }
                return (date: day, label: DateGrouper.sectionLabel(for: day), memos: memos)
            }
    }

    // MARK: - 列表

    private var memoList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if sections.isEmpty {
                    EmptyStateView(filter: filter, hasSearch: !searchText.isEmpty)
                        .padding(.top, 48)
                } else {
                    ForEach(sections, id: \.date) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.label)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            ForEach(section.memos) { memo in
                                MemoRowView(memo: memo)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: Theme.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func showToast(_ text: String) {
        withAnimation { toastMessage = text }
    }
}
