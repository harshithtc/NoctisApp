// ios/Runner/AppDelegate.swift
import UIKit
var blurView: UIVisualEffectView?
func applicationWillResignActive(_ application: UIApplication) {
  guard blurView == nil else { return }
  let blur = UIBlurEffect(style: .regular)
  let v = UIVisualEffectView(effect: blur)
  v.frame = UIScreen.main.bounds
  application.keyWindow?.addSubview(v)
  blurView = v
}
func applicationDidBecomeActive(_ application: UIApplication) {
  blurView?.removeFromSuperview(); blurView = nil
}
