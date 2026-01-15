import SwiftUI

struct AlarmSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var isBarrageEnabled: Bool
    @Binding var preWakeAlarms: Int
    @Binding var postWakeAlarms: Int
    @Binding var barrageInterval: TimeInterval
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $isBarrageEnabled) {
                        HStack {
                            Image(systemName: "bell.badge.waveform.fill")
                                .foregroundStyle(isBarrageEnabled ? .orange : .gray)
                            Text("Multiple Alarms")
                                .fontWeight(.medium)
                        }
                    }
                    .tint(.orange)
                    
                    if isBarrageEnabled {
                        Stepper(value: $preWakeAlarms, in: 0...5) {
                            HStack {
                                Text("Before Wake Up")
                                Spacer()
                                Text("\(preWakeAlarms) alarms")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Stepper(value: $postWakeAlarms, in: 0...30) {
                            HStack {
                                Text("After Wake Up")
                                Spacer()
                                Text("\(postWakeAlarms) alarms")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Picker("Interval", selection: $barrageInterval) {
                            Text("1 min").tag(TimeInterval(60))
                            Text("2 min").tag(TimeInterval(120))
                            Text("5 min").tag(TimeInterval(300))
                            Text("10 min").tag(TimeInterval(600))
                        }
                    }
                } header: {
                    Text("Configuration")
                } footer: {
                    if isBarrageEnabled {
                        Text("This will schedule **\(preWakeAlarms + 1 + postWakeAlarms) alarms total**:\n• \(preWakeAlarms) leading up to wake up\n• 1 at the exact wake up time\n• \(postWakeAlarms) following as a safety net.")
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("A single alarm will fire at your calculated wake up time.")
                    }
                }
                
                if isBarrageEnabled {
                    Section("Visual Preview") {
                        BarrageTimelinePreview(
                            preWakeAlarms: preWakeAlarms,
                            postWakeAlarms: postWakeAlarms
                        )
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Alarm Strategy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct BarrageTimelinePreview: View {
    let preWakeAlarms: Int
    let postWakeAlarms: Int
    
    var body: some View {
        HStack(spacing: 6) {
            // Pre-wake dots
            if preWakeAlarms > 0 {
                ForEach(0..<preWakeAlarms, id: \.self) { _ in
                    Circle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Main wake dot
            Circle()
                .fill(Color.orange)
                .frame(width: 16, height: 16)
                .overlay {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                }
            
            // Post-wake dots
            if postWakeAlarms > 0 {
                ForEach(0..<min(postWakeAlarms, 10), id: \.self) { i in
                    Circle()
                        .fill(Color.red.opacity(0.3 + Double(i) * 0.07))
                        .frame(width: 8, height: 8)
                }
                
                if postWakeAlarms > 10 {
                    Text("+\(postWakeAlarms - 10)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    AlarmSettingsSheet(
        isBarrageEnabled: .constant(true),
        preWakeAlarms: .constant(2),
        postWakeAlarms: .constant(5),
        barrageInterval: .constant(120)
    )
}
