import SwiftUI
import AVFoundation
import UIKit
import UserNotifications
import Lottie

// MARK: - Modelle

enum FriendKind {
    case moehrchen
    case brokkoli
    case karotti
}

struct MeditationFriend: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let kind: FriendKind
}

struct DurationOption: Identifiable, Equatable {
    let id = UUID()
    let minutes: Int
    let stars: Int
}

// MARK: - Atmender Lottie-Charakter (4 s ein, 6 s aus)

struct BreathingLottieCharacterView: View {
    let animationName: String          // z.B. "Moehrchen_Icon_breath"
    let primaryColor: Color            // z.B. Color(hex: "#EA580C")
    let baseDurationSeconds: CGFloat   // Originallänge der Lottie-Animation (in Sekunden)
    let size: CGSize                   // Darstellungsgröße in der Mitte der Karte

    /// Ziel-Gesamtdauer eines Lottie-Loops (Ein + Aus) in Sekunden
    private let cycleDuration: TimeInterval = 10.0
    /// Dauer der Einatmungsphase
    private let inhaleDuration: TimeInterval = 4.0
    /// Dauer der Ausatmungsphase
    private let exhaleDuration: TimeInterval = 6.0

    @State private var isBreathingIn: Bool = true
    @State private var breathCount: Int = 0
    @State private var phaseTimer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            // Figur in Wunschgröße
            LottieView(
                animationName: animationName,
                loopMode: .loop,
                baseDurationSeconds: baseDurationSeconds,
                targetDurationSeconds: cycleDuration
            )
            .frame(width: size.width, height: size.height)

            // Ein-/Ausatmen-Text
            Text(isBreathingIn ? "🌬️ Einatmen" : "😌 Ausatmen")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(primaryColor)
                .animation(nil, value: isBreathingIn)

            // Atemzüge-Zähler
            HStack(spacing: 4) {
                Text("🧘‍♀️")
                Text("\(breathCount)")
                    .monospacedDigit()
                    .animation(nil, value: breathCount)
                Text("Atemzüge")
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(primaryColor.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.9))
            .clipShape(Capsule())
        }
        .onAppear {
            startBreathingLoop()
        }
        .onDisappear {
            phaseTimer?.invalidate()
            phaseTimer = nil
        }
    }

    // MARK: - Atem-Phasen: 4 s Ein, 6 s Aus

    private func startBreathingLoop() {
        phaseTimer?.invalidate()
        isBreathingIn = true

        // Einatmungsphase (4 s)
        let inhaleTimer = Timer.scheduledTimer(withTimeInterval: inhaleDuration, repeats: false) { _ in
            isBreathingIn = false

            // Ausatmungsphase (6 s)
            let exhaleTimer = Timer.scheduledTimer(withTimeInterval: exhaleDuration, repeats: false) { _ in
                // Ein vollständiger Atemzug
                breathCount += 1
                // Zyklus neu starten
                startBreathingLoop()
            }

            RunLoop.main.add(exhaleTimer, forMode: .common)
            self.phaseTimer = exhaleTimer
        }

        RunLoop.main.add(inhaleTimer, forMode: .common)
        self.phaseTimer = inhaleTimer
    }
}

// MARK: - ContentView: Timer + Layout

struct ContentView: View {

    // Freunde & Dauer
    private let friends: [MeditationFriend] = [
        .init(name: "Möhrchen",  kind: .moehrchen),
        .init(name: "Brokkoli",  kind: .brokkoli),
        .init(name: "Karotti",   kind: .karotti)
    ]

    private let durationOptions: [DurationOption] = [
        .init(minutes: 3,  stars: 1),
        .init(minutes: 5,  stars: 2),
        .init(minutes: 10, stars: 3),
        .init(minutes: 15, stars: 4)
    ]

    // Timer State
    @AppStorage("selectedMinutes") private var selectedMinutes = 10
    @AppStorage("timerEndDate") private var timerEndDate: Double?
    @AppStorage("completedSessions") private var completedSessions: Int = 0

    @State private var remainingTime: Int?
    @State private var timer: Timer?
    @State private var audioPlayer: AVAudioPlayer?

    @State private var isStarting = false
    @State private var isRunning = false
    @State private var countdownToStart = 5
    @State private var progress: CGFloat = 1.0

    @State private var selectedFriendIndex: Int = 0

    @State private var showDonate = false
    @State private var showShareSheet = false

    @Environment(\.scenePhase) private var scenePhase

    // Anzeigezeit
    private var displayedSeconds: Int {
        remainingTime ?? selectedMinutes * 60
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // Status-Text
    private var sessionSubtitle: String {
        if isStarting {
            return "Gleich geht es los … \(countdownToStart)"
        } else if isRunning {
            return "Atme ruhig mit deinem Freund."
        } else if remainingTime == nil && progress == 0 {
            return "Meditation beendet."
        } else {
            return "Bereit für eine kleine Pause?"
        }
    }

    // Headline oben
    private var headline: some View {
        Text("Wähle deinen Meditations-Freund")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: "#166534"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Action-Row: Donate + Weiterempfehlen
    private var actionRow: some View {
        HStack(spacing: 12) {
            // Links: Donate
            Button {
                showDonate = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                    Text("Donate")
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.white.opacity(0.9))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Rechts: Weiterempfehlen
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.circle.fill")
                }
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#B91C1C"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.white.opacity(0.9))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Freund → Lottie-Config (Name, Farbe, Größe)

    @ViewBuilder
    private var currentFriendAnimation: some View {
        let friend = friends[selectedFriendIndex]

        switch friend.kind {
        case .moehrchen:
            BreathingLottieCharacterView(
                animationName: "Moehrchen_Icon_breath",
                primaryColor: Color(hex: "#EA580C"),
                baseDurationSeconds: 5.0,                 // Originallänge deiner Lottie
                size: CGSize(width: 190, height: 240)     // Möhrchen-Größe
            )

        case .brokkoli:
            BreathingLottieCharacterView(
                animationName: "Brokkoli_Icon_breath",
                primaryColor: Color(hex: "#10B981"),
                baseDurationSeconds: 5.0,
                size: CGSize(width: 210*0.8, height: 260*0.8)     // Brokkoli etwas größer
            )

        case .karotti:
            BreathingLottieCharacterView(
                animationName: "Karotti_Icon_breath",
                primaryColor: Color(hex: "#F97316"),
                baseDurationSeconds: 10.0,                // falls diese Animation länger ist
                size: CGSize(width: 200*0.7, height: 280*0.7)     // Karotti hoch und schmal
            )
        }
    }
    
    
    private func friendImageName(for kind: FriendKind) -> String {
        switch kind {
        case .moehrchen:
            return "Friend_Moehrchen"
        case .brokkoli:
            return "Friend_Brokkoli"   // Asset-Name in deinem Asset Catalog
        case .karotti:
            return "Friend_Karotti"
        }
    }

    
    

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#F4F5FF").ignoresSafeArea()

            VStack(spacing: 12) {

                actionRow
                    .padding(.top, 20)
                    .padding(.horizontal, 8)

                headline
                    .padding(.top, 0)
                    .padding(.horizontal, 16)

                friendRow
                    .padding(.horizontal, 16)

                characterArea
                    .padding(.horizontal, 16)

                durationRow
                    .padding(.horizontal, 16)

                statusRow
                    .padding(.horizontal, 16)

                progressBar
                    .padding(.horizontal, 16)

                controlRow
                    .padding(.horizontal, 16)

                Spacer(minLength: 8)
            }
        }
        .onAppear {
            setupAudioSession()
            requestNotificationPermission()
            restoreTimerIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                restoreTimerIfNeeded()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["Ich empfehle diesen liebevollen Kinder-Meditations-Timer 🧘‍♀️"])
        }
        .confirmationDialog("Unterstütze diese App", isPresented: $showDonate) {
            Button("💛 Danke – 0,99 €") {}
            Button("💚 Eine Woche Zen – 2,99 €") {}
            Button("💙 Monat der Ruhe – 4,99 €") {}
            Button("💜 Für immer Frieden – 9,99 €") {}
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: - Layout-Bausteine

    private var friendRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(friends.enumerated()), id: \.offset) { index, friend in
                let isSelected = index == selectedFriendIndex

                Button {
                    selectedFriendIndex = index
                } label: {
                    VStack(spacing: 6) {
                        // Icon oben
                        Image(friendImageName(for: friend.kind))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)

                        // Name unten, zentriert
                        Text(friend.name)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isSelected ? Color(hex: "#FAE2C1") : Color.white)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }


    private var characterArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)

            VStack {
                Spacer()
                currentFriendAnimation
                Spacer()
            }
        }
        .frame(height: 320)
    }

    private var statusRow: some View {
        HStack {
            Text(sessionSubtitle)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(formattedTime(displayedSeconds))
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .animation(nil, value: displayedSeconds)
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(Color(hex: "#4B5563"))
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let clamped = max(0, min(1, progress))
            let fillWidth = fullWidth * (1 - clamped)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                Capsule()
                    .fill(Color(hex: "#FAE2C1"))
                    .frame(width: fillWidth, height: 8)
            }
        }
        .frame(height: 12)
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Button {
                isRunning || isStarting ? cancelTimer() : handleStartTap()
            } label: {
                Text(isRunning || isStarting ? "Abbrechen" : "Start")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#C7D2FE"))
                    )
            }
            .buttonStyle(.plain)

            Button {
                resetTimer()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 20, weight: .bold))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "medal.fill")
                Text("\(completedSessions)")
                    .monospacedDigit()
                    .animation(nil, value: completedSessions)
                Text("fertig")
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.3))
            )
        }
    }

    private var durationRow: some View {
        HStack(spacing: 8) {
            ForEach(durationOptions) { option in
                let isSelected = option.minutes == selectedMinutes
                Button {
                    changeDuration(to: option)
                } label: {
                    HStack(spacing: 2) {
                        Text("\(option.minutes)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))

                        Text("Min")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .baselineOffset(1) // optional: leicht nach oben ziehen
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Color(hex: "#FAE2C1") : Color.white)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }



    // MARK: - Timer-Logik

    private func changeDuration(to option: DurationOption) {
        selectedMinutes = option.minutes
        resetTimer()
    }

    private func resetTimer() {
        timer?.invalidate()
        isStarting = false
        isRunning = false
        remainingTime = nil
        progress = 1.0
        audioPlayer?.stop()
        timerEndDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerEnd"])
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio Session Fehler:", error)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error { print("Permission error:", error) }
        }
    }

    private func scheduleTimerEndNotification(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Zeit ist um"
        content.body = "Deine Meditation ist zu Ende."
        content.sound = UNNotificationSound(
            named: UNNotificationSoundName("singingbowl_notification.wav")
        )

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: "timerEnd",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func restoreTimerIfNeeded() {
        guard let endTimestamp = timerEndDate else { return }

        let endDate = Date(timeIntervalSince1970: endTimestamp)
        let now = Date()
        let remaining = Int(endDate.timeIntervalSince(now))

        if remaining <= 0 {
            timer?.invalidate()
            isRunning = false
            remainingTime = nil
            progress = 0
            timerEndDate = nil
            completedSessions += 1
        } else {
            let total = Double(selectedMinutes * 60)
            remainingTime = remaining
            isRunning = true
            progress = CGFloat(Double(remaining) / total)

            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                guard let time = remainingTime else { return }
                if time > 0 {
                    remainingTime = time - 1
                    progress = CGFloat(Double(remainingTime!) / total)
                } else {
                    t.invalidate()
                    isRunning = false
                    remainingTime = nil
                    timerEndDate = nil
                    progress = 0
                    completedSessions += 1
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerEnd"])
                    fadeOutAndStopSound(duration: 10)
                }
            }
        }
    }

    private func handleStartTap() {
        isStarting = true
        countdownToStart = 5

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdownToStart -= 1
            if countdownToStart <= 0 {
                t.invalidate()
                isStarting = false
                startTimer()
            }
        }
    }

    private func startTimer() {
        isRunning = true
        let duration = selectedMinutes * 60
        remainingTime = duration
        progress = 1.0
        playSound()

        let endDate = Date().addingTimeInterval(TimeInterval(duration))
        timerEndDate = endDate.timeIntervalSince1970
        scheduleTimerEndNotification(after: TimeInterval(duration))

        let total = Double(duration)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            guard let time = remainingTime else { return }
            if time > 0 {
                remainingTime = time - 1
                progress = CGFloat(Double(remainingTime!) / total)
            } else {
                t.invalidate()
                isRunning = false
                remainingTime = nil
                timerEndDate = nil
                progress = 0
                completedSessions += 1
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerEnd"])
                fadeOutAndStopSound(duration: 10)
            }
        }
    }

    private func cancelTimer() {
        timer?.invalidate()
        isStarting = false
        isRunning = false
        remainingTime = nil
        progress = 1.0
        timerEndDate = nil
        audioPlayer?.stop()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerEnd"])
    }

    private func playSound() {
        guard let url = Bundle.main.url(forResource: "singingbowl27532", withExtension: "mp3") else {
            print("Sounddatei nicht gefunden")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("AudioPlayer Fehler:", error)
        }
    }

    private func fadeOutAndStopSound(duration: TimeInterval) {
        guard let url = Bundle.main.url(forResource: "singingbowl27532", withExtension: "mp3") else {
            print("Fadeout-Sounddatei nicht gefunden")
            return
        }
        do {
            let fadingPlayer = try AVAudioPlayer(contentsOf: url)
            fadingPlayer.volume = 1.0
            fadingPlayer.play()

            var step = 0
            let steps = 40
            Timer.scheduledTimer(withTimeInterval: duration / 40, repeats: true) { t in
                if step < steps {
                    fadingPlayer.volume -= 1.0 / 40.0
                    step += 1
                } else {
                    fadingPlayer.stop()
                    t.invalidate()
                }
            }
        } catch {
            print("Fadeout-Player Fehler:", error)
        }
    }
}

// MARK: - Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Color Helper

extension Color {
    init(hex: String) {
        let rgb = UInt64(strtoul(hex.replacingOccurrences(of: "#", with: ""), nil, 16))
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
