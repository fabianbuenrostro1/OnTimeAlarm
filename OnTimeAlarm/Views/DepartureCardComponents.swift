import SwiftUI
import MapKit

// MARK: - Traffic Status
enum TrafficStatus {
    case clear, moderate, heavy, unknown

    var color: Color {
        switch self {
        case .clear: return .green
        case .moderate: return .orange
        case .heavy: return .red
        case .unknown: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .clear: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .heavy: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var shortLabel: String {
        switch self {
        case .clear: return "Clear"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .unknown: return ""
        }
    }
}

// MARK: - Timeline Flow View (Simplified for AlarmKit)
struct TimelineFlowView: View {
    let wakeTime: Date
    let prepDuration: TimeInterval
    let leaveTime: Date
    let travelTime: TimeInterval
    let arrivalTime: Date
    let isHeavyTraffic: Bool
    let hasPreWakeAlarm: Bool
    let trafficStatus: TrafficStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pre-Wake Alarm (if enabled)
            if hasPreWakeAlarm {
                let preWakeTime = wakeTime.addingTimeInterval(-5 * 60)
                TimelineRowView(
                    time: preWakeTime,
                    label: "PRE-WAKE",
                    labelColor: .secondary,
                    subtitle: "Gentle reminder",
                    icon: "bell",
                    iconColor: .blue.opacity(0.7),
                    nodeColor: .blue.opacity(0.5),
                    nodeSize: 8,
                    isFirst: true,
                    isLast: false
                )
            }

            // Wake Up Row
            TimelineRowView(
                time: wakeTime,
                label: "WAKE UP",
                labelColor: .orange,
                subtitle: "\(TimeCalculator.formatDuration(prepDuration)) to get ready",
                icon: "bell.fill",
                iconColor: .orange,
                nodeColor: .orange,
                nodeSize: 14,
                showIconInNode: true,
                isFirst: !hasPreWakeAlarm,
                isLast: false
            )

            // Leave Row (emphasized)
            TimelineRowView(
                time: leaveTime,
                label: "LEAVE",
                labelColor: .blue,
                subtitle: isHeavyTraffic ? "Heavy traffic expected" : nil,
                subtitleColor: isHeavyTraffic ? .red : nil,
                icon: "figure.walk.departure",
                iconColor: .blue,
                nodeColor: .blue,
                nodeSize: 14,
                isFirst: false,
                isLast: false,
                isEmphasized: true
            )

            // Arrive Row
            TimelineRowView(
                time: arrivalTime,
                label: "ARRIVE",
                labelColor: .green,
                subtitle: travelSubtitle,
                icon: "mappin.circle.fill",
                iconColor: .green,
                nodeColor: .green,
                nodeSize: 10,
                isFirst: false,
                isLast: true
            )
        }
    }

    private var travelSubtitle: String {
        var text = TimeCalculator.formatDuration(travelTime) + " travel"
        if trafficStatus != .unknown {
            text += " · \(trafficStatus.shortLabel)"
        }
        return text
    }
}

// MARK: - Timeline Row View
private struct TimelineRowView: View {
    let time: Date
    let label: String
    let labelColor: Color
    var subtitle: String?
    var subtitleColor: Color?
    let icon: String
    let iconColor: Color
    let nodeColor: Color
    var nodeSize: CGFloat = 10
    var showIconInNode: Bool = false
    let isFirst: Bool
    let isLast: Bool
    var isEmphasized: Bool = false

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // LEFT: Time (right-aligned toward center, flexible width)
            Text(timeFormatter.string(from: time))
                .font(isEmphasized ? .title3.monospacedDigit() : .callout.monospacedDigit())
                .fontWeight(isEmphasized ? .bold : .medium)
                .foregroundStyle(isEmphasized ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 2)

            // CENTER: Timeline node + connector lines
            VStack(spacing: 0) {
                // Top line (connects to previous)
                Rectangle()
                    .fill(isFirst ? Color.clear : Color(.systemGray4))
                    .frame(width: 2, height: 8)

                // Node
                ZStack {
                    Circle()
                        .fill(nodeColor)
                        .frame(width: nodeSize, height: nodeSize)

                    if showIconInNode {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                // Bottom line (connects to next)
                Rectangle()
                    .fill(isLast ? Color.clear : Color(.systemGray4))
                    .frame(width: 2, height: 24)
            }
            .frame(width: 16)

            // RIGHT: Label + subtitle (left-aligned)
            VStack(alignment: .leading, spacing: 3) {
                // Label with icon
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(labelColor)
                }

                // Subtitle
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(subtitleColor ?? .secondary)
                }
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, isEmphasized ? 4 : 2)
    }
}

// MARK: - Compact Location Footer View
struct CompactLocationFooterView: View {
    let originName: String
    let destinationName: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "house.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(originName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Image(systemName: "mappin.and.ellipse")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(destinationName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Flow Layout (Horizontal Wrap)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
