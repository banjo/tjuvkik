import AppKit

// `tjuvkik <command>` runs the command line tool and exits; without one the app starts.
MainActor.assumeIsolated { CommandLineTool.runIfCommand(CommandLine.arguments) }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
