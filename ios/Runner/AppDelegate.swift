import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CmfKeepAwake")
    else { return }
    let channel = FlutterMethodChannel(
      name: "cmf/keep_awake",
      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "setKeepAwake" {
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    let memoryChannel = FlutterMethodChannel(
      name: "cmf/device_memory",
      binaryMessenger: registrar.messenger())
    memoryChannel.setMethodCallHandler { call, result in
      if call.method == "memoryInfo" {
        // os_proc_available_memory: what this process may still allocate
        // before jetsam — the honest number for "will this model fit".
        result([
          "availBytes": Int64(os_proc_available_memory()),
          "totalBytes": Int64(ProcessInfo.processInfo.physicalMemory),
          "lowMemory": false,
        ])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
