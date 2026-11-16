import ServiceManagement

/// Keeps the login item in step with `launchAtLogin` in the config.
@MainActor
enum LaunchAtLogin {
    private static var service: SMAppService { .mainApp }

    /// Turned on, but waiting for you in System Settings → General → Login Items.
    static var needsApproval: Bool { service.status == .requiresApproval }

    static var isEnabled: Bool { service.status == .enabled }

    /// Returns why it failed, for the menu.
    static func apply(_ enabled: Bool) -> String? {
        let status = service.status
        do {
            if enabled, status != .enabled, status != .requiresApproval {
                try service.register()
            } else if !enabled, status == .enabled || status == .requiresApproval {
                try service.unregister()
            }
            return nil
        } catch {
            return "Couldn't \(enabled ? "turn on" : "turn off") launch at login: \(error.localizedDescription)"
        }
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
