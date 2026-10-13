import SwiftUI

/// User-chosen text size for chat / message content (transcript + composer).
/// Persisted in `UserDefaults` via `@AppStorage(ChatFontSize.storageKey)`, so the
/// session "…" menu and the Settings row edit the same value and both update live.
///
/// Scaling is applied by stepping the inherited `DynamicTypeSize` down, so every
/// text-style font in the chat (`Theme.Typography.messageBody` = `.body`, etc.)
/// shrinks proportionally while still honoring the user's system text size:
/// at the default `.large` (17pt body) 小 → `.small` (15pt, ≈0.88×) and
/// 极小 → `.xSmall` (14pt, ≈0.82×). Available on iOS 15+, so iOS 18 safe.
enum ChatFontSize: String, CaseIterable, Identifiable {
    case normal, small, extraSmall

    static let storageKey = "codeg.chat.fontSize"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .normal: "Normal"
        case .small: "Small"
        case .extraSmall: "Extra Small"
        }
    }

    /// How many Dynamic Type steps below the inherited size to render.
    var steps: Int {
        switch self {
        case .normal: 0
        case .small: 2
        case .extraSmall: 3
        }
    }

    /// The inherited size stepped down by `steps`, clamped at `.xSmall`.
    func adjusted(_ base: DynamicTypeSize) -> DynamicTypeSize {
        let all = DynamicTypeSize.allCases
        guard steps > 0, let index = all.firstIndex(of: base) else { return base }
        return all[max(all.startIndex, index - steps)]
    }
}

/// Applies the persisted `ChatFontSize` to a chat content subtree.
private struct ChatFontSizeModifier: ViewModifier {
    @AppStorage(ChatFontSize.storageKey) private var fontSize: ChatFontSize = .normal
    @Environment(\.dynamicTypeSize) private var baseSize

    func body(content: Content) -> some View {
        content.dynamicTypeSize(fontSize.adjusted(baseSize))
    }
}

extension View {
    /// Scale chat / message text by the user's chosen `ChatFontSize`.
    func chatFontSize() -> some View {
        modifier(ChatFontSizeModifier())
    }
}

/// The "Font Size" single-choice picker, shared by the session actions menu and
/// the Settings page so both edit the same persisted value.
struct ChatFontSizePicker: View {
    @AppStorage(ChatFontSize.storageKey) private var fontSize: ChatFontSize = .normal

    var body: some View {
        Picker(selection: $fontSize) {
            ForEach(ChatFontSize.allCases) { size in
                Text(size.titleKey).tag(size)
            }
        } label: {
            Label("Font Size", systemImage: "textformat.size")
        }
    }
}
