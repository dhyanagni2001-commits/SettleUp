//
//  Effects.swift
//  SplitWiseClone
//
//  Reusable motion: animated mesh background, glass cards, shimmer
//  skeletons, scroll-driven lazy reveal, staggered entrances, confetti.
//

import SwiftUI

/// UI tests pass -uiTesting; continuous animations are frozen there so
/// XCTest's idle detection isn't kept busy.
let reduceContinuousMotion = ProcessInfo.processInfo.arguments.contains("-uiTesting")

/// Spotify-style backdrop: near-black base with a tinted header gradient
/// that slowly "breathes", like a playlist page picking up its cover color.
struct AppBackground: View {
    var tint: Color = .brand

    var body: some View {
        TimelineView(.animation(paused: reduceContinuousMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let reach = 0.42 + 0.06 * sin(t * 0.8)
            LinearGradient(stops: [
                .init(color: tint.opacity(0.45), location: 0),
                .init(color: tint.opacity(0.12), location: reach * 0.6),
                .init(color: .base, location: reach),
            ], startPoint: .top, endPoint: .bottom)
        }
        .background(Color.base)
        .ignoresSafeArea()
    }
}

extension View {
    /// Flat dark card. Deliberately not `.glassEffect`: on iOS 26.5 a glass
    /// layer inserted at runtime swallows taps on the buttons inside it
    /// (newly created groups couldn't be opened).
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card.opacity(0.92), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Items gently scale and fade in as they scroll into the viewport.
    /// Kept to opacity + scale (no blur) so long lists scroll at full frame rate.
    func lazyReveal() -> some View {
        scrollTransition(.animated(.smooth(duration: 0.35))) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.4)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
    }

    /// One-shot entrance: rises and fades in after an `index`-based delay.
    func staggeredAppear(_ index: Int) -> some View {
        modifier(StaggeredAppear(delay: Double(index) * 0.05))
    }

    func shimmer() -> some View { modifier(Shimmer()) }
}

private struct StaggeredAppear: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .onAppear {
                withAnimation(.smooth(duration: 0.5).delay(delay)) { visible = true }
            }
    }
}

private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                    .rotationEffect(.degrees(20))
                    .visualEffect { effect, proxy in effect.offset(x: phase * proxy.size.width * 1.5) }
                    .blendMode(.plusLighter)
            }
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

struct SkeletonCard: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14).frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 8) {
                Capsule().frame(width: 140, height: 14)
                Capsule().frame(width: 90, height: 10)
            }
            Spacer()
            Capsule().frame(width: 60, height: 14)
        }
        .foregroundStyle(.white.opacity(0.18))
        .shimmer()
        .glassCard()
    }
}

/// Burst of spinning confetti every time `trigger` changes.
struct ConfettiBurst: View {
    let trigger: Int

    private struct Piece {
        let angle = Double.random(in: -.pi * 0.95 ... -.pi * 0.05)
        let speed = Double.random(in: 350...850)
        let spin = Double.random(in: -12...12)
        let size = Double.random(in: 8...16)
        let color: Color = [.brand, .brand, .white, Color(hex: 0x169C46), Color(hex: 0xB3B3B3)].randomElement() ?? .brand
    }

    @State private var pieces: [Piece] = []
    @State private var start: Date?
    private let duration = 2.6

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let t = timeline.date.timeIntervalSince(start)
                guard t < duration else { return }
                for piece in pieces {
                    var ctx = context
                    ctx.opacity = 1 - t / duration
                    ctx.translateBy(x: size.width / 2 + cos(piece.angle) * piece.speed * t,
                                    y: size.height * 0.45 + sin(piece.angle) * piece.speed * t + 700 * t * t)
                    ctx.rotate(by: .radians(piece.spin * t))
                    ctx.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                             with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onChange(of: trigger) {
            pieces = (0..<120).map { _ in Piece() }
            start = .now
            Task {
                try? await Task.sleep(for: .seconds(duration))
                start = nil
            }
        }
    }
}

struct SectionTitle: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
