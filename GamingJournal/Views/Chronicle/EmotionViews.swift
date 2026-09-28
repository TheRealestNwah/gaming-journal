import SwiftUI

extension EmotionGroup {
    var color: Color { Color(hex: hex) }
}

/// A felt emotion as a small capsule: icon, name and intensity pips.
struct EmotionChip: View {
    let emotion: Emotion
    var intensity: Int = 2

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: emotion.systemImage)
            Text(emotion.label)
            IntensityPips(intensity: intensity)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(emotion.group.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(emotion.group.color.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(emotion.group.color.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(emotion.label), \(IntensityPips.describe(intensity))")
    }
}

/// One to three small flames showing how strongly something was felt.
struct IntensityPips: View {
    let intensity: Int

    static func describe(_ intensity: Int) -> String {
        switch intensity {
        case ...1: "faint"
        case 2: "strong"
        default: "overwhelming"
        }
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...FeltEmotion.intensityRange.upperBound, id: \.self) { level in
                Circle()
                    .frame(width: 4, height: 4)
                    .opacity(level <= intensity ? 1 : 0.25)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Emotions grouped by family. Tapping a chip adds it faintly, then stronger, then removes it.
struct EmotionPicker: View {
    @Binding var draft: EntryDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(EmotionGroup.allCases) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.label)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(Theme.fadedInk)
                    FlowLayout(spacing: 6) {
                        ForEach(Emotion.inGroup(group)) { emotion in
                            chip(emotion)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ emotion: Emotion) -> some View {
        let intensity = draft.intensity(of: emotion)
        let color = emotion.group.color
        return Button {
            draft.cycle(emotion)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: emotion.systemImage)
                Text(emotion.label)
                if let intensity {
                    IntensityPips(intensity: intensity)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(intensity == nil ? Theme.fadedInk : color)
            .background(intensity == nil ? Color.clear : color.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(intensity == nil ? Theme.rule : color, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emotion.label)
        .accessibilityValue(intensity.map(IntensityPips.describe) ?? "not felt")
        .accessibilityHint("Tap to strengthen, or to clear at full strength")
        .sensoryFeedback(.selection, trigger: intensity)
    }
}

/// Lays children out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width && !row.indices.isEmpty {
                let nextY = row.y + row.height + spacing
                rows.append(Row(indices: [index], y: nextY, width: size.width, height: size.height))
                continue
            }
            row.indices.append(index)
            row.width = needed
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
