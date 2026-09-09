import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let linphone = LinphonePlugin()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LinphonePlugin") else {
      return
    }
    let messenger = registrar.messenger()

    FlutterMethodChannel(name: LinphonePlugin.methodChannel, binaryMessenger: messenger)
      .setMethodCallHandler { [weak linphone] call, result in
        linphone?.handle(call, result: result)
      }
    FlutterEventChannel(name: LinphonePlugin.eventChannel, binaryMessenger: messenger)
      .setStreamHandler(linphone)
  }
}
