import Foundation

/// "Pulse" easing: an exponential, viscous-fluid style curve with a quick start
/// and a long soft tail. Same math as the open-source smoothscroll.js (MIT),
/// which in turn is based on Michael Herf's viscous fluid curve.
struct PulseEasing {
    var scale: Double

    private func raw(_ t: Double) -> Double {
        let x = t * scale
        if x < 1 {
            return x - (1 - exp(-x))
        }
        let start = exp(-1.0)
        let tail = 1 - exp(-(x - 1))
        return start + tail * (1 - start)
    }

    /// Maps progress t in [0, 1] to eased progress in [0, 1].
    func callAsFunction(_ t: Double) -> Double {
        if t >= 1 { return 1 }
        if t <= 0 { return 0 }
        return raw(t) / raw(1)
    }
}
