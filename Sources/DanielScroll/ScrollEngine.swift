import AppKit
import CoreGraphics
import QuartzCore

/// Marks events we post ourselves so our own tap lets them through ("DSCR").
private let syntheticMarker: Int64 = 0x4453_4352

/// Intercepts discrete mouse-wheel events, swallows them, and replays the
/// distance as a stream of small pixel-based scroll events, one per frame.
final class ScrollEngine: NSObject {
    private struct Animation {
        let dx: Double
        let dy: Double
        let start: CFTimeInterval
        var doneX = 0.0
        var doneY = 0.0
    }

    private let settings = Settings.shared
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var displayLink: CADisplayLink?

    private var animations: [Animation] = []
    private var remainderX = 0.0
    private var remainderY = 0.0
    private var lastWheelTime: CFTimeInterval = 0
    private var lastDirX = 0.0
    private var lastDirY = 0.0
    private var lastFlags: CGEventFlags = []

    var isRunning: Bool { tap != nil }

    // MARK: - Event tap lifecycle

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<ScrollEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("DanielScroll: could not create event tap (Accessibility permission missing?)")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        resetAnimation()
    }

    // MARK: - Input

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passThrough = Unmanaged.passUnretained(event)

        // macOS disables taps that are slow or when secure input kicks in; turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return passThrough
        }
        guard type == .scrollWheel else { return passThrough }

        // Our own synthetic events.
        if event.getIntegerValueField(.eventSourceUserData) == syntheticMarker { return passThrough }
        guard settings.enabled else { return passThrough }

        // Trackpads and Magic Mouse send continuous (pixel) events; they're already smooth.
        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return passThrough }

        if settings.isExcluded(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
            return passThrough
        }

        let rawY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        var rawX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        if !settings.horizontalSmoothing {
            if rawY == 0 { return passThrough }   // purely horizontal: leave it alone
            rawX = 0
        }
        if rawX == 0 && rawY == 0 { return passThrough }

        var dirY = rawY == 0 ? 0.0 : (rawY > 0 ? 1.0 : -1.0)
        var dirX = rawX == 0 ? 0.0 : (rawX > 0 ? 1.0 : -1.0)
        // With "Natural scrolling" on, macOS has already inverted this event, and it
        // will invert our synthetic events again on the way out. Undo the first flip.
        if NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice == true {
            dirY = -dirY
            dirX = -dirX
        }
        if settings.reverseDirection {
            dirY = -dirY
            dirX = -dirX
        }

        let now = CACurrentMediaTime()

        // Changing direction cancels whatever is still in flight.
        if dirY != lastDirY || dirX != lastDirX {
            animations.removeAll()
            remainderX = 0
            remainderY = 0
        }

        // Fast consecutive notches in the same direction scroll further.
        var factor = 1.0
        if settings.accelerationEnabled, dirY == lastDirY, dirX == lastDirX {
            let elapsedMs = (now - lastWheelTime) * 1000
            if elapsedMs < settings.accelerationDelta {
                let f = (1 + 50 / max(elapsedMs, 1)) / 2
                if f > 1 { factor = min(f, settings.accelerationMax) }
            }
        }

        lastWheelTime = now
        lastDirX = dirX
        lastDirY = dirY
        lastFlags = event.flags

        let distance = settings.stepSize * factor
        animations.append(Animation(dx: dirX * distance, dy: dirY * distance, start: now))
        startDisplayLinkIfNeeded()

        return nil  // swallow the original notch
    }

    // MARK: - Animation

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let link = screen.displayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func frame(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let duration = max(settings.animationTime, 1) / 1000
        let ease = PulseEasing(scale: settings.pulseScale)

        var sumX = remainderX
        var sumY = remainderY
        var stillRunning: [Animation] = []
        stillRunning.reserveCapacity(animations.count)

        for var anim in animations {
            let t = (now - anim.start) / duration
            let p = ease(t)
            let stepX = anim.dx * p - anim.doneX
            let stepY = anim.dy * p - anim.doneY
            anim.doneX += stepX
            anim.doneY += stepY
            sumX += stepX
            sumY += stepY
            if t < 1 { stillRunning.append(anim) }
        }
        animations = stillRunning

        // Post whole pixels; carry the fractions to the next frame so nothing drifts.
        let outX = sumX.rounded(.towardZero)
        let outY = sumY.rounded(.towardZero)
        remainderX = sumX - outX
        remainderY = sumY - outY

        if outX != 0 || outY != 0 {
            post(dx: Int32(clamping: Int(outX)), dy: Int32(clamping: Int(outY)))
        }

        if animations.isEmpty {
            resetAnimation()
        }
    }

    private func post(dx: Int32, dy: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: dy,
            wheel2: dx,
            wheel3: 0
        ) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.flags = lastFlags
        if let location = CGEvent(source: nil)?.location {
            event.location = location
        }
        event.post(tap: .cgSessionEventTap)
    }

    private func resetAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        animations.removeAll()
        remainderX = 0
        remainderY = 0
    }
}
