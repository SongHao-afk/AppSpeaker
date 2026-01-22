import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Flutter plugins (pub.dev)
    GeneratedPluginRegistrant.register(with: self)

    // ✅ Register LoopbackPlugin (custom)
    if let controller = window?.rootViewController as? FlutterViewController,
       let registrar = controller.registrar(forPlugin: "LoopbackPlugin") {
      LoopbackPlugin.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
