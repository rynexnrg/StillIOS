import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager.shared
    @State private var selectedTab: Int = 0
    @State private var timerMinutes: Double = 15
    @State private var alarmDate: Date = Date()
    
    var body: some View {
        ZStack {
            // Dunkler, tiefer Hintergrund
            LinearGradient(colors: [Color.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                Text("STILL")
                    .font(.system(size: 20, weight: .light, design: .monospaced))
                    .tracking(8)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 20)
                
                // Tab-Auswahl (Liquid-Glass Segmented Control)
                HStack {
                    TabButton(title: "Fokus", isSelected: selectedTab == 0) { selectedTab = 0 }
                    TabButton(title: "Timer", isSelected: selectedTab == 1) { selectedTab = 1 }
                    TabButton(title: "Wecker", isSelected: selectedTab == 2) { selectedTab = 2 }
                }
                .padding(4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.horizontal)
                
                Spacer()
                
                // Content je nach Tab
                if selectedTab == 0 {
                    focusView
                } else if selectedTab == 1 {
                    timerView
                } else {
                    alarmView
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Fokus View
    var focusView: some View {
        VStack(spacing: 40) {
            Button(action: {
                if audioManager.isFocusActive {
                    audioManager.stopFocus()
                } else {
                    audioManager.startFocus()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(audioManager.isFocusActive ? Color.white : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: audioManager.isFocusActive ? .white.opacity(0.2) : .clear, radius: 20)
                    
                    Text(audioManager.isFocusActive ? "Aktiv" : "Starten")
                        .font(.system(size: 22, weight: .ultraLight))
                        .foregroundColor(.white)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: audioManager.isFocusActive)
        }
    }
    
    // MARK: - Timer View
    var timerView: some View {
        VStack(spacing: 30) {
            if audioManager.isTimerRunning {
                Text(formatTime(audioManager.remainingTimerTime))
                    .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white)
                
                Button("Abbrechen") {
                    audioManager.stopTimer()
                }
                .buttonStyle(GlassButtonStyle())
            } else {
                Text("\(Int(timerMinutes)) min")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(.white)
                
                Slider(value: $timerMinutes, in: 1...120, step: 1)
                    .accentColor(.white)
                    .padding(.horizontal, 40)
                
                Button("Timer Starten") {
                    audioManager.startTimer(duration: timerMinutes * 60)
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
    }
    
    // MARK: - Wecker View
    var alarmView: some View {
        VStack(spacing: 30) {
            if let activeAlarm = audioManager.alarmTime {
                Text("Wecker gestellt auf")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.5))
                
                Text(activeAlarm, style: .time)
                    .font(.system(size: 54, weight: .ultraLight))
                    .foregroundColor(.white)
                
                Button("Deaktivieren") {
                    audioManager.cancelAlarm()
                }
                .buttonStyle(GlassButtonStyle())
            } else {
                DatePicker("", selection: $alarmDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                
                Button("Wecker Stellen") {
                    audioManager.setAlarm(targetTime: alarmDate)
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Helper UI Components
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .regular : .light))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(Capsule())
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .light))
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 32)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}