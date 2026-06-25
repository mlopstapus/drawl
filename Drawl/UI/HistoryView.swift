import SwiftUI

public class HistoryViewModel: ObservableObject {
    @Published public var entries: [HistoryEntry] = []
    @Published public var searchQuery: String = "" {
        didSet {
            loadEntries()
        }
    }
    
    private let store: HistoryStore
    private let preferencesStore: PreferencesStore
    
    public init(store: HistoryStore, preferencesStore: PreferencesStore) {
        self.store = store
        self.preferencesStore = preferencesStore
        purgeAndLoad()
    }
    
    public func purgeAndLoad() {
        do {
            try store.purgeOldEntries(olderThanDays: preferencesStore.historyRetentionDays)
            loadEntries()
        } catch {
            print("Failed to purge and load history: \(error)")
        }
    }
    
    public func loadEntries() {
        do {
            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.entries = try store.fetchAll()
            } else {
                self.entries = try store.search(query: searchQuery)
            }
        } catch {
            print("Failed to fetch history: \(error)")
        }
    }
    
    public func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(text, forType: .string)
    }
}

struct GroupedHistory: Identifiable {
    var id: Date { date }
    let date: Date
    let entries: [HistoryEntry]
}

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var hoveredEntryId: UUID? = nil
    
    var groupedEntries: [GroupedHistory] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: viewModel.entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        return dict.map { GroupedHistory(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 500, height: 600)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
        )
        .onAppear {
            viewModel.purgeAndLoad()
        }
    }
    
    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search transcriptions...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.body)
            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .padding()
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.entries.isEmpty {
            emptyStateView
        } else {
            historyListView
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        Spacer()
        VStack(spacing: 15) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.purple.opacity(0.6))
            
            if viewModel.searchQuery.isEmpty {
                Text("No transcriptions yet")
                    .font(.headline)
                Text("Hold ⌥+Space to start dictating.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No matches found")
                    .font(.headline)
                Text("Try a different search query.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        Spacer()
    }
    
    @ViewBuilder
    private var historyListView: some View {
        List {
            ForEach(groupedEntries) { group in
                Section(header: Text(formatSectionHeader(group.date))
                    .font(.headline)
                    .foregroundColor(.purple)
                    .padding(.vertical, 4)) {
                        
                    ForEach(group.entries) { entry in
                        HistoryRowView(
                            entry: entry,
                            isHovered: hoveredEntryId == entry.id,
                            onCopy: {
                                viewModel.copyToClipboard(entry.text)
                            }
                        )
                        .onHover { isHovered in
                            if isHovered {
                                hoveredEntryId = entry.id
                            } else if hoveredEntryId == entry.id {
                                hoveredEntryId = nil
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private var footerView: some View {
        HStack {
            Text("\(viewModel.entries.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Clear History") {
                // Clear history triggers purging older than -1 days to remove all
                try? viewModel.purgeAndLoad()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.purple)
            .opacity(0.8)
            .disabled(viewModel.entries.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
    }
    
    private func formatSectionHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

struct HistoryRowView: View {
    let entry: HistoryEntry
    let isHovered: Bool
    let onCopy: () -> Void
    
    @State private var justCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let appName = entry.sourceAppName, !appName.isEmpty {
                    Label(appName, systemImage: "macwindow")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .bold()
                } else {
                    Label("Unknown App", systemImage: "questionmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatTimestamp(entry.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(entry.text)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Label(String(format: "%.1fs", entry.duration), systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isHovered || justCopied {
                    Button(action: {
                        onCopy()
                        withAnimation {
                            justCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                justCopied = false
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            Text(justCopied ? "Copied!" : "Copy")
                        }
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
