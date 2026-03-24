import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)

    // ✅ Force register LoopbackPlugin (vì bạn add Swift file thủ công)
    if let registrar = self.registrar(forPlugin: "LoopbackPlugin") {
      LoopbackPlugin.register(with: registrar)
      NSLog("✅✅ Forced LoopbackPlugin.register OK")
    } else {
      NSLog("❌❌ registrar(forPlugin: LoopbackPlugin) = nil")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}


