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

// MARK: - Header (Optional for Map-First, but kept for context if needed)
struct TimelineHeaderView: View {
    let targetTime: Date
    @Binding var isEnabled: Bool
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Arrive by")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                
                Text(timeFormatter.string(from: targetTime))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            Toggle(isOn: $isEnabled) {
                Text(isEnabled ? "Alarm On" : "Alarm Off")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isEnabled ? .green : .secondary)
            }
            .tint(.green)
            .fixedSize()
        }
    }
}

// MARK: - Timeline Flow (Hero Style)
// MARK: - Timeline Flow (Data Table Style)
// MARK: - Timeline Flow (Vertical Style)
struct TimelineFlowView: View {
    let wakeTime: Date
    let prepDuration: TimeInterval
    let leaveTime: Date
    let travelTime: TimeInterval
    let arrivalTime: Date
    
    // Dynamic values from parent
    let isHeavyTraffic: Bool
    let alarmCount: Int
    let isBarrageEnabled: Bool

    // Data for Visualization
    let preWakeAlarms: Int
    let postWakeAlarms: Int
    let barrageInterval: TimeInterval

    // Traffic status for inline display
    let trafficStatus: TrafficStatus
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }
    
    private var amPmFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // --- Pre-Wake Alarms (if barrage enabled) ---
            if isBarrageEnabled && preWakeAlarms > 0 {
                // Show only the first/earliest alarm
                let firstAlarmTime = wakeTime.addingTimeInterval(-Double(preWakeAlarms) * barrageInterval)
                timelineRow(
                    time: firstAlarmTime,
                    isMajor: false,
                    isLast: false,
                    showTopLine: false,
                    showBottomLine: true,
                    content: {
                        HStack(spacing: 4) {
                            Image(systemName: "alarm.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue.opacity(0.6))
                            Text("Alarm 1")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    },
                    nodeColor: .blue.opacity(0.5)
                )

                // Show "+N more" if there are additional pre-wake alarms
                if preWakeAlarms > 1 {
                    condensedAlarmRow(
                        count: preWakeAlarms - 1,
                        color: .blue.opacity(0.5),
                        showTopLine: true,
                        showBottomLine: true
                    )
                }
            }
            
            // --- Wake Up Row (Centerpiece) ---
            timelineRow(
                time: wakeTime,
                isMajor: false,
                isLast: false,
                showTopLine: isBarrageEnabled && preWakeAlarms > 0, // Connects to pre-wake if existing
                showBottomLine: true,
                customNode: {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 2)
                            )
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                },
                content: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WAKE UP")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Text(TimeCalculator.formatDuration(prepDuration) + " prep")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            )
            
            // --- Post-Wake Alarms (if barrage enabled) ---
            if isBarrageEnabled && postWakeAlarms > 0 {
                // Show only the summary - no individual alarms
                condensedAlarmRow(
                    count: postWakeAlarms,
                    color: .red.opacity(0.5),
                    showTopLine: true,
                    showBottomLine: true
                )
            }
            
            // --- Leave Row (Major) ---
            timelineRow(
                time: leaveTime,
                isMajor: true,
                isLast: false,
                showTopLine: true, // Always connected to logic above
                content: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LEAVE HOME")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        if isHeavyTraffic {
                            Label("Heavy Traffic", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                },
                nodeColor: .blue
            )
            
            // --- Arrive Row ---
            timelineRow(
                time: arrivalTime,
                isMajor: false,
                isLast: true,
                content: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ARRIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "car.fill")
                                .font(.caption2)
                            Text(TimeCalculator.formatDuration(travelTime))
                                .font(.caption)

                            if trafficStatus != .unknown {
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Image(systemName: trafficStatus.icon)
                                    .font(.caption2)
                                    .foregroundStyle(trafficStatus.color)
                                Text(trafficStatus.shortLabel)
                                    .font(.caption)
                                    .foregroundStyle(trafficStatus.color)
                            }
                        }
                        .foregroundStyle(trafficStatus == .heavy ? .red : .secondary)
                    }
                },
                nodeColor: .green
            )
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Alarm Segment Row (Vertical Dots on Line)
    @ViewBuilder
    private func alarmSegmentRow(preWake: Int, postWake: Int) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // Left: Empty space (same width as time column)
            Spacer()
                .frame(width: 100)
            
            // Center: Vertical Dot Sequence
            VStack(spacing: 4) {
                // Pre-wake dots (top, fading in)
                ForEach(0..<min(preWake, 3), id: \.self) { i in
                    Circle()
                        .fill(Color.blue.opacity(0.3 + Double(i) * 0.2))
                        .frame(width: 6, height: 6)
                }
                
                // Post-wake dots (bottom, fading out)
                ForEach(0..<min(postWake, 3), id: \.self) { i in
                    Circle()
                        .fill(Color.red.opacity(0.6 - Double(i) * 0.15))
                        .frame(width: 6, height: 6)
                }
                
                // Hint for more
                if postWake > 3 {
                    Text("+\(postWake - 3)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func timelineRow<Content: View, Node: View>(
        time: Date,
        isMajor: Bool,
        isLast: Bool,
        showTopLine: Bool = true,
        showBottomLine: Bool = true,
        @ViewBuilder customNode: @escaping () -> Node = { EmptyView() },
        @ViewBuilder content: () -> Content,
        nodeColor: Color = .gray.opacity(0.5)
    ) -> some View {
        HStack(alignment: .center, spacing: 16) { 
            // Left: Time
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(timeFormatter.string(from: time))
                    .font(isMajor ? .system(size: 32, weight: .bold, design: .rounded) : .callout.monospacedDigit())
                    .fontWeight(isMajor ? .bold : .medium)
                    .foregroundStyle(isMajor ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize()
                
                Text(amPmFormatter.string(from: time))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .trailing)
            
            // Center: Timeline Gutter
            ZStack(alignment: .center) { 
                // Bottom Vertical Line
                if !isLast && showBottomLine {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .offset(y: 12)
                }
                
                // Top Line
                if showTopLine && time != wakeTime {
                     Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 2)
                        .frame(height: 12)
                        .offset(y: -12)
                }

                // Node
                if Node.self == EmptyView.self {
                    Circle()
                        .fill(nodeColor)
                        .frame(width: isMajor ? 16 : 8, height: isMajor ? 16 : 8)
                        .background(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                } else {
                    customNode()
                }
            }
            .frame(width: 20) // Slightly wider for custom nodes
            
            // Right: Content
            content()
                .padding(.vertical, isMajor ? 0 : 0)
            
            Spacer()
        }
        .padding(.vertical, isMajor ? 8 : 4)
    }

    @ViewBuilder
    private func condensedAlarmRow(
        count: Int,
        color: Color,
        showTopLine: Bool,
        showBottomLine: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // Left: Empty (no time for condensed row)
            Spacer()
                .frame(width: 100)

            // Center: Dotted line indicator
            ZStack(alignment: .center) {
                // Connecting lines
                VStack(spacing: 2) {
                    if showTopLine {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 2, height: 8)
                    }
                    // Dots to indicate "more"
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                    }
                    if showBottomLine {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 2, height: 8)
                    }
                }
            }
            .frame(width: 20)

            // Right: Summary text
            HStack(spacing: 4) {
                Image(systemName: "ellipsis")
                    .font(.caption2)
                    .foregroundStyle(color)
                Text("+\(count) more alarm\(count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Alarm Status Footer (New)
// MARK: - Alarm Status Footer (Visual Preview Style)
struct AlarmStatusFooter: View {
    let alarmCount: Int
    let isBarrageEnabled: Bool
    @Binding var isEnabled: Bool
    
    // New Goal-Oriented Context
    let targetTime: Date
    let destinationName: String
    
    // Data for Visualization
    let preWakeAlarms: Int
    let postWakeAlarms: Int
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Text Status (Goal Oriented)
            VStack(alignment: .leading, spacing: 2) {
                if isEnabled {
                    Text("Arrive by \(timeFormatter.string(from: targetTime))")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("at \(destinationName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Alarms Off")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap to enable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Right: Toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(isBarrageEnabled ? .orange : .green)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Barrage Visualizer (Dots & Bell)
struct BarrageVisualizer: View {
    let preWakeAlarms: Int
    let postWakeAlarms: Int
    
    var body: some View {
        HStack(spacing: 3) {
            // Pre-wake dots
            if preWakeAlarms > 0 {
                ForEach(0..<min(preWakeAlarms, 4), id: \.self) { _ in
                    Circle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
                if preWakeAlarms > 4 {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
            
            // Main wake bell
            ZStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 20, height: 20)
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
            }
            
            // Post-wake dots
            if postWakeAlarms > 0 {
                ForEach(0..<min(postWakeAlarms, 4), id: \.self) { i in
                    Circle()
                        .fill(Color.red.opacity(0.3 + Double(i) * 0.07))
                        .frame(width: 6, height: 6)
                }
                if postWakeAlarms > 4 {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }
}

// MARK: - Generic Footer (Locations)
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

// MARK: - Explicit Alarm Times List
struct AlarmTimesListView: View {
    let alarmTimes: [Date]
    let wakeUpTime: Date
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Alarms (\(alarmTimes.count))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            // Times Flow
            FlowLayout(spacing: 6) {
                ForEach(alarmTimes, id: \.self) { time in
                    let isWake = Calendar.current.isDate(time, equalTo: wakeUpTime, toGranularity: .minute)
                    
                    Text(timeFormatter.string(from: time))
                        .font(.caption2.monospacedDigit())
                        .fontWeight(isWake ? .bold : .regular)
                        .foregroundStyle(isWake ? .orange : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isWake ? Color.orange.opacity(0.15) : Color(.systemGray6))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isWake ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
