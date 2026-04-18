import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = resolvedWindowFrame(defaultFrame: self.frame)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    DispatchQueue.main.async {
      self.setFrame(windowFrame, display: true)
    }
  }

  private func resolvedWindowFrame(defaultFrame: NSRect) -> NSRect {
    let environment = ProcessInfo.processInfo.environment
    guard let rawBounds = environment["GOZDAR_WINDOW_BOUNDS"] else {
      return defaultFrame
    }

    let values = rawBounds
      .split(separator: ",")
      .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }

    guard values.count == 4 else {
      return defaultFrame
    }

    return NSRect(
      x: values[0],
      y: values[1],
      width: values[2],
      height: values[3]
    )
  }
}
