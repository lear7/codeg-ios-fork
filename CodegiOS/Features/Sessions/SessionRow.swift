import SwiftUI

/// One conversation row in ``SessionListView`` / ``ActivityView``: a single,
/// borderless line. The agent's brand avatar (with a small status-tinted dot)
/// anchors the left, the title fills the middle, and the trailing edge shows a
/// live pulse while running or a compact relative time otherwise. Selection
/// (iPad) tints a subtle rounded background rather than drawing a card border.
struct SessionRow: View {
    let conversation: ConversationSummary
    let isSelected: Bool
    /// A dim folder tag shown before the timestamp, or `nil` to omit it (e.g.
    /// inside a Chats folder group, where the folder is already the header).
    /// Used by Activity/Search and the cross-folder Pinned group for context.
    var folderName: String?
    /// Tap handler. When `nil`, the row is a non-interactive preview (no Button,
    /// no context menu) — used inside ``SessionSectionCard``'s capped preview,
    /// where the whole card owns the tap.
    var onTap: (() -> Void)? = nil
    /// When set, a long-press context menu offers Pin/Unpin (the label reflects
    /// `conversation.isPinned`). `.swipeActions` doesn't work inside the list's
    /// `LazyVStack`, so a context menu is the toggle affordance.
    var onTogglePin: (() -> Void)? = nil
    /// When set, the same menu offers a destructive Delete. The host confirms
    /// before it removes the session (`deleteSessionConfirmation`).
    var onDelete: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            Button(action: onTap) { rowContent }
                .buttonStyle(PressableRowStyle())
                .contextMenu {
                    if let onTogglePin {
                        Button(action: onTogglePin) {
                            Label(conversation.isPinned ? "Unpin" : "Pin",
                                  systemImage: conversation.isPinned ? "pin.slash" : "pin")
                        }
                    }
                    if let onDelete {
                        if onTogglePin != nil { Divider() }
                        Button(role: .destructive) {
                            // Defer until the menu has dismissed, or the confirmation
                            // alert is dropped along with the context menu.
                            let requestDelete = onDelete
                            Task { @MainActor in requestDelete() }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
        } else {
            // Display-only preview (inside SessionSectionCard): the whole card
            // owns the tap, so the row renders without a Button or context menu.
            rowContent
        }
    }

    /// The row's visual content, shared by the interactive (Button) rendering and
    /// the non-interactive preview rendering.
    private var rowContent: some View {
        HStack(spacing: 11) {
            avatar

            (conversation.trimmedTitle.map { Text(verbatim: $0) } ?? Text("Untitled session"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let folderName {
                Label(folderName, systemImage: "folder")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 104, alignment: .trailing)
            }

            trailing
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.accent.opacity(0.18))
            }
        }
        .contentShape(Rectangle())
    }

    /// Small agent avatar with a status-tinted dot badge in the corner (the live
    /// state additionally shows a pulse on the trailing edge).
    private var avatar: some View {
        AgentAvatar(agent: conversation.agentType, size: 26)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(conversation.status.tint)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 1.5))
                    .offset(x: 1.5, y: 1.5)
            }
    }

    @ViewBuilder
    private var trailing: some View {
        if conversation.status.isLive {
            LivePulse()
        } else {
            Text(RelativeTime.compact(from: conversation.updatedAt))
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize()
        }
    }
}

// MARK: - Relative time

/// Compact relative-time formatting shared by rows.
///
/// `RelativeDateTimeFormatter` is not `Sendable`, so the shared instance is
/// pinned to the main actor — every caller here renders from a SwiftUI view
/// body, which is already main-actor isolated.
@MainActor
enum RelativeTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.dateTimeStyle = .numeric
        return f
    }()

    /// Phrased relative time ("2h ago", "now", "in 5m") for prose contexts.
    static func string(from date: Date, relativeTo reference: Date = Date()) -> String {
        let interval = reference.timeIntervalSince(date)
        if interval >= 0, interval < 45 { return "now" }
        return formatter.localizedString(for: date, relativeTo: reference)
    }

    /// Ultra-compact magnitude for dense list rows: "now", "5m", "2h", "6d",
    /// then a short date ("Mar 5") past a week. No "ago"/"in" suffix.
    static func compact(from date: Date, relativeTo reference: Date = Date()) -> String {
        let interval = reference.timeIntervalSince(date)
        if interval < 60 { return "now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 7 { return "\(days)d" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Delete confirmation

/// Confirms a destructive session delete. Title and actions reuse the session
/// detail alert (`Delete Session?` / Cancel / Delete) so zh-Hans stays in the
/// string catalog. `presenting:` hands the row to the confirm button even if
/// SwiftUI clears the binding while dismissing the alert.
struct DeleteSessionConfirmation: ViewModifier {
    @Binding var pending: ConversationSummary?
    let onConfirm: (ConversationSummary) -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Delete Session?",
            isPresented: Binding(
                get: { pending != nil },
                set: { showing in if !showing { pending = nil } }
            ),
            presenting: pending
        ) { conversation in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onConfirm(conversation) }
        } message: { conversation in
            Self.message(for: conversation)
        }
    }

    /// Localized confirmation body. The title is an argument of the catalog
    /// string, so a user-written name is not looked up as its own key.
    private static func message(for conversation: ConversationSummary) -> Text {
        let title = conversation.trimmedTitle ?? String(localized: "Untitled session")
        return Text("“\(title)” will be permanently deleted. This can't be undone.")
    }
}

extension View {
    func deleteSessionConfirmation(
        _ pending: Binding<ConversationSummary?>,
        onConfirm: @escaping (ConversationSummary) -> Void
    ) -> some View {
        modifier(DeleteSessionConfirmation(pending: pending, onConfirm: onConfirm))
    }
}
