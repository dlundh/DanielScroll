# DanielScroll

A small menu-bar app that makes mouse-wheel scrolling smooth on macOS (14+).

## Build and run

```bash
./build.sh             # builds build/DanielScroll.app
./build.sh --install   # also copies it to /Applications and launches it
```

Or open `Package.swift` in Xcode.

On first launch, macOS asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility). The menu-bar icon shows ⚠︎ until it's granted, then smoothing starts on its own.

## How it works

1. A `CGEventTap` catches every scroll-wheel event in the session.
2. Trackpad and Magic Mouse events (`scrollWheelEventIsContinuous == 1`) pass straight through.
3. Each discrete wheel notch is swallowed and queued as an animation of `stepSize` pixels.
   Fast consecutive notches in the same direction get an acceleration multiplier.
4. A `CADisplayLink` runs once per screen refresh. Every frame it eases each queued
   animation along a "pulse" curve and posts one small pixel-based scroll event with the sum.
5. Posted events are tagged in `eventSourceUserData` so the tap ignores its own output.

| File | Purpose |
|---|---|
| `ScrollEngine.swift` | Event tap, acceleration, per-frame animation, posting |
| `Easing.swift` | Pulse easing curve |
| `Settings.swift` | UserDefaults-backed settings |
| `MenuBarController.swift` | Menu-bar UI, per-app exclusions, launch at login |
| `main.swift` | App delegate, Accessibility permission flow |

## Tuning

Menu bar → Step size / Animation. Values not in the menu can be set directly:

```bash
defaults write com.daniel.DanielScroll pulseScale -float 4        # curve sharpness
defaults write com.daniel.DanielScroll accelerationMax -float 3   # max speed-up
defaults write com.daniel.DanielScroll accelerationDelta -float 50 # ms window
```

## Credits

The pulse easing curve uses the same math as the open-source
[smoothscroll.js](https://github.com/gblazex/smoothscroll-for-websites) (MIT), based on
Michael Herf's viscous-fluid curve.
