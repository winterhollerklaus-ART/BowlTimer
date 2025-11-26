import SwiftUI
import AVFoundation
import AVKit
import UIKit

// MARK: - Video Background View (NO LOOP)
struct VideoBackground: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .disabled(true)
            .onAppear {
                player.isMuted = true
                player.actionAtItemEnd = .pause   // stop at end, no loop
            }
    }
}

struct ContentView: View {

    // MARK: - States & Storage
    @AppStorage("selectedMinutes") private var selectedMinutes = 10
    @State private var remainingTime: Int?
    @State private var timer: Timer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isStarting = false
    @State private var isRunning = false
    @State private var countdownToStart = 5
    @State private var progress: CGFloat = 1.0

    @State private var showShareSheet = false
    @State private var showDonate = false

    // Toggle: Image vs Video
    @State private var useVideo = false

    // Video Player (tree.mp4 muss im Bundle sein)
    private var videoPlayer: AVPlayer = {
        let url = Bundle.main.url(forResource: "tree", withExtension: "mp4")!
        return AVPlayer(url: url)
    }()

    // MARK: - Status Text
    private var statusText: String {
        if isStarting {
            return "Starting in \(countdownToStart)…"
        } else if let remaining = remainingTime {
            return "Remaining: \(remaining / 60):\(String(format: "%02d", remaining % 60))"
        } else {
            return ""
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {

            // 1) Vollflächiger Hintergrund in #E1CCA8
            Color(hex: "#E1CCA8")
                .edgesIgnoringSafeArea(.all)

            // 2) Video oder Bild darüber
            if useVideo {
                VideoBackground(player: videoPlayer)
                    .edgesIgnoringSafeArea(.all)
                    // Farb-Tint über das Video legen, damit #E1CCA8 sichtbar ist
                    .overlay(
                        Color(hex: "#E1CCA8")
                            .edgesIgnoringSafeArea(.all)
                            .opacity(1)   // nach Geschmack 0.2–0.6
                    )
            } else {
                Image("TibetischeKlangschale_hoch")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
            }

            // 3) UI-Layer
            mainLayout
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["I recommend this beautiful meditation app 🙏"])
        }
        .confirmationDialog("Support this app", isPresented: $showDonate) {
            Button("💛 $0.99") {}
            Button("💚 $2.99") {}
            Button("💙 $4.99") {}
            Button("💜 $9.99") {}
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Main Layout
    private var mainLayout: some View {
        VStack(spacing: 0) {

            topBar
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer().frame(height: 80)

            statusSection
                .offset(y: 40)
                .padding(.bottom, -10)

            timerRing
                .offset(y: -40)
                .padding(.bottom, 20)

            Spacer()

            VStack(spacing: 24) {
                timeSelection
                pickerSection
                startStopButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Donate Button (links)
            Button("Donate") {
                showDonate = true
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.3))
            .clipShape(Capsule())

            Spacer()

            // Toggle Image / Video (zentral)
            Button(action: { useVideo.toggle() }) {
                Text(useVideo ? "Image" : "Video")
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.3))
                    .clipShape(Capsule())
            }

            Spacer()

            // Share (rechts)
            Button { showShareSheet = true } label: {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red.opacity(0.9))
            }
        }
    }

    // MARK: - Status Text
    private var statusSection: some View {
        Text(statusText)
            .font(.title3)
            .foregroundColor(.black.opacity(0.7))
            .frame(height: 28)
    }

    // MARK: - Timer Ring
    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 8)
                .frame(width: 280, height: 280)
                .blur(radius: 1)

            Circle()
                .stroke(Color.black.opacity(0.15), lineWidth: 6)
                .frame(width: 280, height: 280)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.green,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 280, height: 280)
                .shadow(color: Color.green.opacity(0.7), radius: 6)
                .animation(.linear(duration: 1.0), value: progress)
        }
    }

    // MARK: - Start/Stop Button
    private var startStopButton: some View {
        Button(action: {
            isRunning || isStarting ? cancelTimer() : handleStartTap()
        }) {
            Text(isRunning || isStarting ? "Cancel" : "Start")
                .font(.system(size: 26, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.7))
                .clipShape(Capsule())
                .foregroundColor(isRunning ? .red : .black)
        }
    }

    // MARK: - Time Choice Buttons
    private var timeSelection: some View {
        HStack(spacing: 16) {
            ForEach([5, 10, 15], id: \.self) { value in
                Button(action: {
                    selectedMinutes = value
                }) {
                    Text("\(value) Min")
                        .font(.system(size: 18, weight: .medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(selectedMinutes == value ? Color.green.opacity(0.3) : Color.white.opacity(0.3))
                        )
                        .foregroundColor(.black)
                }
            }
        }
    }

    // MARK: - Picker
    private var pickerSection: some View {
        VStack(spacing: 8) {
            Text("Duration: \(selectedMinutes) minutes")
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))

            Slider(
                value: Binding(
                    get: { Double(selectedMinutes) },
                    set: { selectedMinutes = Int($0) }
                ),
                in: 1...60,
                step: 1
            )
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 10)
    }

    // MARK: - Timer Logic
    func handleStartTap() {
        isStarting = true
        countdownToStart = 5

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdownToStart -= 1
            if countdownToStart == 0 {
                t.invalidate()
                isStarting = false

                if useVideo {
                    adjustPlaybackRate(for: videoPlayer)
                }

                startTimer()
            }
        }
    }

    /// Streckt das Video (z.B. 7s) auf die Timer-Dauer (z.B. 5min) per Playback-Rate
    func adjustPlaybackRate(for player: AVPlayer) {
        guard let item = player.currentItem else { return }

        let videoDuration = item.asset.duration.seconds      // z.B. 7.0
        let timerDuration = Double(selectedMinutes * 60)     // z.B. 300.0

        let rate = videoDuration / timerDuration             // z.B. 7 / 300 ≈ 0.023

        player.seek(to: .zero)

        // WICHTIG: direkt mit Rate starten (kein extra player.play())
        player.playImmediately(atRate: Float(rate))
    }

    func startTimer() {
        isRunning = true
        remainingTime = selectedMinutes * 60
        progress = 1.0
        playSound()

        let total = Double(selectedMinutes * 60)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            guard let time = remainingTime else { return }

            if time > 0 {
                remainingTime! -= 1
                withAnimation(.linear(duration: 1)) {
                    progress = CGFloat(Double(remainingTime!) / total)
                }
            } else {
                t.invalidate()
                isRunning = false
                remainingTime = nil
                fadeOutAndStopSound(duration: 10)

                if useVideo {
                    videoPlayer.pause()
                    videoPlayer.seek(to: .zero)
                }
            }
        }
    }

    func cancelTimer() {
        timer?.invalidate()
        isStarting = false
        isRunning = false
        remainingTime = nil
        progress = 1.0
        audioPlayer?.stop()

        if useVideo {
            videoPlayer.pause()
            videoPlayer.seek(to: .zero)
        }
    }

    func playSound() {
        guard let url = Bundle.main.url(forResource: "singingbowl27532", withExtension: "mp3") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch { }
    }

    func fadeOutAndStopSound(duration: TimeInterval) {
        guard let url = Bundle.main.url(forResource: "singingbowl27532", withExtension: "mp3") else { return }
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
        } catch { }
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

// MARK: - Hex Color
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
