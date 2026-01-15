import SwiftUI

struct EmptyStateView: View {
    var onAddTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "alarm.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Departures")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first departure to start calculating your optimal wake-up time.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onAddTapped) {
                Label("Add Departure", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            
            Spacer()
        }
    }
}

#Preview {
    EmptyStateView(onAddTapped: {})
}
