import UIKit

/// Controls the device screen's brightness so the display can act as a fill
/// light for front-camera capture.
///
/// The brightness value lives on `UIScreen`, but `UIScreen.main` is deprecated
/// as of iOS 26, so the screen is resolved through the foreground-active window
/// scene instead.
enum ScreenBrightness {
    static var activeScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
    }

    /// Raises brightness to maximum, returning the level to restore later.
    static func raiseToMaximum() -> CGFloat? {
        guard let screen = activeScreen else { return nil }
        let previous = screen.brightness
        screen.brightness = 1
        return previous
    }

    static func restore(to level: CGFloat?) {
        guard let level, let screen = activeScreen else { return }
        screen.brightness = level
    }
}
