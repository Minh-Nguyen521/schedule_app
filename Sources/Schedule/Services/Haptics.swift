import UIKit

enum Haptics {
    /// Ticking should feel different from un-ticking — a small confirmation that
    /// the tap registered without having to look at the row.
    static func tick(completed: Bool) {
        if completed {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
