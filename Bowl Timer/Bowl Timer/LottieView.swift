// LottieView.swift

import SwiftUI
import Lottie

/// Spielt eine Lottie-Animation ab und stretcht die Dauer
/// von baseDurationSeconds auf targetDurationSeconds.
struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let baseDurationSeconds: CGFloat
    let targetDurationSeconds: CGFloat

    init(
        animationName: String,
        loopMode: LottieLoopMode = .loop,
        baseDurationSeconds: CGFloat,
        targetDurationSeconds: CGFloat
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.baseDurationSeconds = baseDurationSeconds
        self.targetDurationSeconds = targetDurationSeconds
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        // Geschwindigkeit so wählen, dass baseDuration → targetDuration gestreckt wird.
        // speed = originalDauer / gewünschteDauer
        let speed = baseDurationSeconds / targetDurationSeconds

        let animationView = LottieAnimationView(name: animationName)
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        animationView.contentMode = .scaleAspectFit
        animationView.play()

        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: view.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // nichts nötig
    }
}
