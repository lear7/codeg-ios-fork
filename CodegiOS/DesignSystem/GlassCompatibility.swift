import SwiftUI

/// Liquid Glass styling that stays on the system APIs for iOS 26 and falls
/// back to materials / bordered buttons on iOS 18.
///
/// The iOS 26 branches call the same `glassEffect`, `GlassEffectContainer`,
/// and glass button styles the call sites used directly. Earlier systems never
/// reference those symbols.
enum CodegGlass {
    /// `.regular` glass, or ultra-thin material.
    case regular
    /// `.regular.tint(color)` glass, or ultra-thin material plus that wash.
    case tinted(Color)
}

extension View {
    /// `glassEffect(_:in:)` on iOS 26. On iOS 18, an ultra-thin material clipped
    /// to `shape`, with `color` layered behind the content when tinted.
    @ViewBuilder
    func codegGlass<S: Shape>(_ style: CodegGlass = .regular, in shape: S) -> some View {
        if #available(iOS 26, *) {
            switch style {
            case .regular:
                self.glassEffect(.regular, in: shape)
            case .tinted(let color):
                self.glassEffect(.regular.tint(color), in: shape)
            }
        } else {
            switch style {
            case .regular:
                self.background(.ultraThinMaterial, in: shape)
            case .tinted(let color):
                // Color sits above the material and behind the content. Call
                // sites already pass a low-opacity wash (the old glass tint).
                self.background(color, in: shape)
                    .background(.ultraThinMaterial, in: shape)
            }
        }
    }

    /// `.buttonStyle(.glass)` on iOS 26; `.bordered` on iOS 18.
    @ViewBuilder
    func codegGlassButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// `.buttonStyle(.glassProminent)` on iOS 26; `.borderedProminent` on iOS 18.
    @ViewBuilder
    func codegGlassProminentButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

/// Groups sibling glass views so iOS 26 can sample and morph them together.
/// On iOS 18 the children lay out exactly as they do inside the container
/// (each one supplies its own material).
struct CodegGlassContainer<Content: View>: View {
    var spacing: CGFloat
    private var content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}
