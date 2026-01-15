import SwiftUI
import MapKit

// MARK: - Header
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
            .fixedSize() // Prevents expanding
        }
    }
}

// MARK: - Timeline Flow
struct TimelineFlowView: View {
    let wakeTime: Date
    let prepDuration: TimeInterval
    let leaveTime: Date
    let travelTime: TimeInterval
    let arrivalTime: Date
    
    // Dynamic values from parent
    let isHeavyTraffic: Bool
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // 1. Wake Up
            VStack(alignment: .leading, spacing: 2) {
                Text(timeFormatter.string(from: wakeTime))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("Wake Up")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Link: Prep
            VStack(spacing: 2) {
                Text(TimeCalculator.formatDuration(prepDuration))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 2)
            }
            .padding(.bottom, 6)
            
            Spacer()
            
            // 2. Leave (HERO)
            VStack(alignment: .center, spacing: 2) {
                Text(timeFormatter.string(from: leaveTime))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Leave")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }
            // Lift the hero slightly to stand out
            .offset(y: -4) 
            
            Spacer()
            
            // Link: Travel
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "car.fill")
                        .font(.caption2)
                    Text(TimeCalculator.formatDuration(travelTime))
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundStyle(isHeavyTraffic ? .red : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isHeavyTraffic ? Color.red.opacity(0.1) : Color(.systemGray5))
                .clipShape(Capsule())
                
                Rectangle()
                    .fill(isHeavyTraffic ? Color.red.opacity(0.3) : Color(.systemGray5))
                    .frame(height: 2)
            }
            .padding(.bottom, 6)
            
            Spacer()
            
            // 3. Arrive (Visual Checkpoint)
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeFormatter.string(from: arrivalTime))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("Arrive")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Location Footer
struct CompactLocationFooterView: View {
    let originName: String
    let destinationName: String
    let trafficStatus: DepartureCardView.TrafficStatus
    
    var body: some View {
        HStack {
            // Origin -> Dest
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
            }
            
            Spacer()
            
            // Traffic Badge
            HStack(spacing: 4) {
                Image(systemName: trafficStatus.icon)
                    .font(.caption2)
                Text(trafficStatus.label)
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundStyle(trafficStatus.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(trafficStatus.color.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}
