import UIKit
import Flutter
import GoogleMaps // Required for Google Maps integration

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ✅ Add your Google Maps API Key below
    GMSServices.provideAPIKey("AIzaSyA36IDthLI6L-zG-fTi54jtsqh-DxGbWjU")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
