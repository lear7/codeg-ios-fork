import SwiftUI

/// A user-chosen text size level. Used by two independent persisted settings:
/// - the app font size (`appStorageKey`), applied once at `RootView`, scaling
///   every screen;
/// - the chat font size (`storageKey`), applied to the session detail content
///   (transcript + composer) on top of the app size.
///
/// Scaling steps the inherited `DynamicTypeSize` down, so every text-style font
/// (and `Font.mono`, which is `relativeTo: .body`) shrinks proportionally while
/// still honoring the user's system text size: at the default `.large` (17pt
/// body) 小 → `.small` (15pt, ≈0.88×), 极小 → `.xSmall` (14pt, ≈0.82×). Because
/// each modifier steps down from what it inherits, the chat size stacks on the
/// app size (clamped at `.xSmall`). iOS 15+ APIs only, so iOS 18 safe.
enum ChatFontSize: String, CaseIterable, Identifiable {
    case normal, small, extraSmall

    /// Session / chat content size (会话字体大小).
    static let storageKey = "codeg.chat.fontSize"
    /// Whole-app size (全局字体大小).
    static let appStorageKey = "codeg.app.fontSize"

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

/// Applies the `ChatFontSize` persisted under `key` to a subtree.
private struct FontSizeLevelModifier: ViewModifier {
    @AppStorage private var fontSize: ChatFontSize
    @Environment(\.dynamicTypeSize) private var baseSize

    init(key: String) {
        _fontSize = AppStorage(wrappedValue: .normal, key)
    }

    func body(content: Content) -> some View {
        content.dynamicTypeSize(fontSize.adjusted(baseSize))
    }
}

extension View {
    /// Scale the whole app by the App Font Size setting. Apply once, at the root.
    func appFontSize() -> some View {
        modifier(FontSizeLevelModifier(key: ChatFontSize.appStorageKey))
    }

    /// Scale chat / message content by the Chat Font Size setting (on top of the
    /// app size). Apply once, on the session detail content.
    func chatFontSize() -> some View {
        modifier(FontSizeLevelModifier(key: ChatFontSize.storageKey))
    }
}

/// A single-choice size picker bound to the setting persisted under `key`.
struct FontSizeLevelPicker: View {
    let title: LocalizedStringKey
    @AppStorage private var fontSize: ChatFontSize

    init(_ title: LocalizedStringKey, key: String) {
        self.title = title
        _fontSize = AppStorage(wrappedValue: .normal, key)
    }

    var body: some View {
        Picker(selection: $fontSize) {
            ForEach(ChatFontSize.allCases) { size in
                Text(size.titleKey).tag(size)
            }
        } label: {
            Label(title, systemImage: "textformat.size")
        }
    }
}

/// The Chat Font Size picker (session "…" menu + Settings).
struct ChatFontSizePicker: View {
    var body: some View {
        FontSizeLevelPicker("Chat Font Size", key: ChatFontSize.storageKey)
    }
}

/// The App Font Size picker (Settings only).
struct AppFontSizePicker: View {
    var body: some View {
        FontSizeLevelPicker("App Font Size", key: ChatFontSize.appStorageKey)
    }
}
