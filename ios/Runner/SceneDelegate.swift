import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var blurEffectView: UIVisualEffectView?

  override func sceneWillResignActive(_ scene: UIScene) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    if blurEffectView == nil {
      let blurEffect = UIBlurEffect(style: .dark)
      blurEffectView = UIVisualEffectView(effect: blurEffect)
      blurEffectView?.frame = windowScene.windows.first?.frame ?? UIScreen.main.bounds
      windowScene.windows.first?.addSubview(blurEffectView!)
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    blurEffectView?.removeFromSuperview()
    blurEffectView = nil
  }
}
