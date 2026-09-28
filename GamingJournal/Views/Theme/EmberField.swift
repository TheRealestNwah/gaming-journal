import SwiftUI

/// Embers drifting up from a campfire below the screen. Decorative only; drawn as nothing when
/// Reduce Motion is on.
struct EmberField: View {
    var count = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear
                .accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for ember in EmberMotion.embers(count: count) {
                        let position = ember.position(at: time, in: size)
                        let radius = ember.radius * position.fade
                        let rect = CGRect(x: position.point.x - radius, y: position.point.y - radius,
                                          width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: rect.insetBy(dx: -radius * 1.5, dy: -radius * 1.5)),
                                     with: .color(Theme.emberGlow.opacity(0.18 * position.fade)))
                        context.fill(Path(ellipseIn: rect),
                                     with: .color(Theme.emberGlow.opacity(0.85 * position.fade)))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Deterministic ember paths: each rises from the bottom edge, sways, and fades out near the top.
enum EmberMotion {
    struct Ember: Equatable {
        /// Horizontal start, 0…1 of the width.
        var x: Double
        /// Seconds to cross the height.
        var duration: Double
        /// Offset into the cycle so they don't rise together.
        var phase: Double
        var sway: Double
        var radius: Double

        struct Position {
            var point: CGPoint
            /// 1 near the fire, 0 at the top.
            var fade: Double
        }

        func position(at time: TimeInterval, in size: CGSize) -> Position {
            let progress = ((time / duration + phase).truncatingRemainder(dividingBy: 1) + 1)
                .truncatingRemainder(dividingBy: 1)
            let y = size.height * (1 - progress)
            let x = size.width * x + sin((time + phase * 10) * 1.3) * sway
            return Position(point: CGPoint(x: x, y: y), fade: max(0, 1 - progress))
        }
    }

    static func embers(count: Int) -> [Ember] {
        var generator = SeededGenerator(seed: 0xE3BE)
        return (0..<max(0, count)).map { _ in
            Ember(
                x: .random(in: 0...1, using: &generator),
                duration: .random(in: 6...12, using: &generator),
                phase: .random(in: 0...1, using: &generator),
                sway: .random(in: 6...22, using: &generator),
                radius: .random(in: 1.2...2.8, using: &generator)
            )
        }
    }
}
