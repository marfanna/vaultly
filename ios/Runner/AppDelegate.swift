import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var blurEffectView: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    if blurEffectView == nil {
      let blurEffect = UIBlurEffect(style: .dark)
      blurEffectView = UIVisualEffectView(effect: blurEffect)
      blurEffectView?.frame = window?.frame ?? UIScreen.main.bounds
      window?.addSubview(blurEffectView!)
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    blurEffectView?.removeFromSuperview()
    blurEffectView = nil
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
