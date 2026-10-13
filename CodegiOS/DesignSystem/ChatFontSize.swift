import SwiftUI
import UIKit

/// A user-chosen text size level. Used by two independent persisted settings:
/// - the app font size (`appStorageKey`), applied once at `RootView`, scaling
///   every screen;
/// - the chat font size (`storageKey`), applied to the session detail content
///   (transcript + composer) on top of the app size.
///
/// Scaling steps the inherited `DynamicTypeSize` down, so every text-style font
/// (and `Font.mono`, which is `relativeTo: .body`) shrinks with the system text
/// size. At the default `.large` the body ramp is 17pt, and the levels land on:
/// - 普通 → `.large` (17pt)
/// - 小 → `.small` (15pt, two steps)
/// - 极小 → `.xSmall` (14pt, three steps) then a one-time 13/14 layout scale
///
/// `DynamicTypeSize` has no case below `.xSmall`. UIKit's body style at
/// `.extraSmall` is 14pt, so there is no Dynamic Type step that yields ~13pt.
/// 极小 therefore keeps the three-step clamp and, only when that clamp is
/// `.xSmall`, lays the subtree out 14/13 larger and scales it by 13/14. Body
/// text lands on 13pt, wrapping and selection stay aligned with the glyphs, and
/// the scale is applied at most once — a second 极小 (chat on top of app, or
/// the reverse) does not compound past ~13pt. Larger system sizes never hit the
/// floor, so an accessibility category still only moves three steps down.
/// iOS 16+ layout APIs, so iOS 18 safe.
enum ChatFontSize: String, CaseIterable, Identifiable {
    case normal, small, extraSmall

    /// Session / chat content size (会话字体大小).
    static let storageKey = "codeg.chat.fontSize"
    /// Whole-app size (全局字体大小).
    static let appStorageKey = "codeg.app.fontSize"

    /// Body point size 极小 should render at the system default text size.
    /// `.xSmall` body is 14pt, so this is one point under the Dynamic Type floor.
    static let extraSmallBodyTarget: CGFloat = 13

    /// `extraSmallBodyTarget / bodyPointSize(.xSmall)`. 1 when `.xSmall` body is
    /// already at or under the target (no smaller Dynamic Type step to invent).
    static let extraSmallFloorScale: CGFloat = {
        let measured = bodyPointSize(.xSmall)
        guard measured > extraSmallBodyTarget + 0.25 else { return 1 }
        return extraSmallBodyTarget / measured
    }()

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

    /// Dynamic Type step plus the optional 14pt → 13pt floor scale.
    ///
    /// `inheritedFloorScale` is the scale an ancestor level already applied
    /// (1 when none). The floor scale is not applied again: chat stacks on app
    /// by stepping Dynamic Type further, and stops at the same ~13pt floor.
    func resolution(from base: DynamicTypeSize, inheritedFloorScale: CGFloat = 1) -> Resolution {
        let dynamicType = adjusted(base)
        let alreadyTightened = inheritedFloorScale < 1
        let appliesFloorScale = self == .extraSmall && dynamicType == .xSmall && !alreadyTightened
        let bodyScale: CGFloat
        if appliesFloorScale {
            bodyScale = Self.extraSmallFloorScale
        } else if alreadyTightened {
            bodyScale = inheritedFloorScale
        } else {
            bodyScale = 1
        }
        return Resolution(
            dynamicType: dynamicType,
            bodyScale: bodyScale,
            appliesFloorScale: appliesFloorScale
        )
    }

    /// Body point size of `size` on the iOS Dynamic Type ramp (`.body`).
    static func bodyPointSize(_ size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: size.uiContentSizeCategory)
        return UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits).pointSize
    }

    /// Body point size after Dynamic Type and the floor scale.
    static func renderedBodyPointSize(_ resolution: Resolution) -> CGFloat {
        bodyPointSize(resolution.dynamicType) * resolution.bodyScale
    }

    struct Resolution: Equatable {
        var dynamicType: DynamicTypeSize
        /// 1, or `extraSmallFloorScale` once the `.xSmall` floor has been tightened.
        var bodyScale: CGFloat
        /// This level is the one that introduces `bodyScale` (ancestors must not repeat it).
        var appliesFloorScale: Bool
    }
}

extension DynamicTypeSize {
    /// UIKit category for the same Dynamic Type step. Used to read the body
    /// point size; not a new `DynamicTypeSize` case.
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

/// Scale already applied by an ancestor font-size level. 1 means the Dynamic
/// Type floor has not been tightened. Descendants read this so 极小 does not
/// stack a second 13/14 scale.
private struct BodyFloorScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    fileprivate var codegBodyFloorScale: CGFloat {
        get { self[BodyFloorScaleKey.self] }
        set { self[BodyFloorScaleKey.self] = newValue }
    }
}

/// Applies the `ChatFontSize` persisted under `key` to a subtree.
private struct FontSizeLevelModifier: ViewModifier {
    @AppStorage private var fontSize: ChatFontSize
    @Environment(\.dynamicTypeSize) private var baseSize
    @Environment(\.codegBodyFloorScale) private var inheritedFloorScale

    init(key: String) {
        _fontSize = AppStorage(wrappedValue: .normal, key)
    }

    func body(content: Content) -> some View {
        let resolved = fontSize.resolution(from: baseSize, inheritedFloorScale: inheritedFloorScale)
        // The floor-scale wrapper stays in the tree at scale 1 so choosing 极小
        // does not rebuild the subtree (live session streams sit under the root).
        content
            .dynamicTypeSize(resolved.dynamicType)
            .modifier(BodyFloorScale(scale: resolved.appliesFloorScale ? resolved.bodyScale : 1))
            .environment(\.codegBodyFloorScale, resolved.bodyScale)
    }
}

/// Lays `content` out `1/scale` larger and draws it at `scale`, so a `.xSmall`
/// body (14pt) renders at 13pt. Scale 1 is a pass-through: same proposal, no
/// visible transform. The wrapper itself is stable across both values.
private struct BodyFloorScale: ViewModifier {
    var scale: CGFloat

    func body(content: Content) -> some View {
        FloorScaleLayout(scale: scale) {
            content.scaleEffect(scale, anchor: .topLeading)
        }
    }
}

/// Reports the parent's size and proposes `bounds / scale` to its child.
/// `scaleEffect` then draws that larger layout back into `bounds`, which is
/// the same wrap a 13pt body would get in the original width. At scale 1 the
/// parent's proposal is forwarded unchanged.
private struct FloorScaleLayout: Layout {
    var scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        if scale >= 1 {
            return child.sizeThatFits(proposal)
        }
        if let width = proposal.width, let height = proposal.height,
           width.isFinite, height.isFinite, width > 0, height > 0 {
            return CGSize(width: width, height: height)
        }
        let natural = child.sizeThatFits(proposal)
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        // Scale 1 forwards the parent's proposal so flexible dimensions (a nil
        // height, a scroll view) stay flexible. Below 1, the child is measured
        // in the pre-scale space and `scaleEffect` draws it back into `bounds`.
        let proposed = scale >= 1
            ? proposal
            : ProposedViewSize(width: bounds.width / scale, height: bounds.height / scale)
        child.place(at: bounds.origin, anchor: .topLeading, proposal: proposed)
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
