/// The widget extension never runs the Lock Screen buttons (the app does), but the
/// shared intents need these names to compile here.
enum RestTimerControl {
    @MainActor static func addThirty() {}
    @MainActor static func done() {}
}
