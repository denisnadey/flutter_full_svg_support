import Cocoa
import FlutterMacOS

public class FullSvgFlutterJsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "io.full_svg.flutter_js",
      binaryMessenger: registrar.messenger)
    let instance = FullSvgFlutterJsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // The Dart bridge talks directly to the bundled quickjs-ng via FFI.
    // No method-channel calls are expected at runtime; return notImplemented
    // for any unexpected invocations so the failure mode is loud.
    result(FlutterMethodNotImplemented)
  }
}
