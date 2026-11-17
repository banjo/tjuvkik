import Foundation
import IOKit.ps
import TjuvkikCore

/// The panels the app ships to start from, in Resources/starters/panels.
struct Starter: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var tile: Tile
    /// Tools from `requires` that aren't installed. Empty when it can be used.
    var missing: [String]
    var isDemo: Bool { name.hasPrefix("demo-") }
}

enum Starters {
    /// The folder they're read from, or nil outside the app bundle (`swift run`).
    static var directory: URL? { Bundle.main.url(forResource: "starters", withExtension: nil) }

    /// Every starter that loads, in the order of the table in #20. `battery` is left out without a battery.
    static func all(path: String) -> [Starter] {
        guard let directory else { return [] }
        let battery = hasBattery
        let starters = ConfigLoader.panelNames(in: directory).compactMap { name -> Starter? in
            guard name != "battery" || battery, case .success(let tile) = ConfigLoader.panel(name, in: directory) else { return nil }
            return Starter(name: name, tile: tile, missing: RequiredTools.missing(tile.requires, path: path))
        }
        let rank = { (name: String) in order.firstIndex(of: name) ?? order.count }
        return starters.sorted { rank($0.name) < rank($1.name) }
    }

    /// The order they're listed in.
    static let order = ["disk", "cpu-memory", "battery", "github", "demo-agents", "demo-slack"]

    static var hasBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        return list.contains { source in
            let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
            return description?[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }
}
