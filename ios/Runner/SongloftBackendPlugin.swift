import Flutter
import Foundation

#if HAS_SONGLOFT_BACKEND
@_silgen_name("MobileStart")
private func linkedMobileStart(
    _ dataDir: UnsafeRawPointer?,
    _ musicDir: UnsafeRawPointer?,
    _ port: Int,
    _ ret0: UnsafeMutablePointer<Int>?,
    _ error: UnsafeMutableRawPointer?
) -> ObjCBool
@_silgen_name("MobileStop") private func linkedMobileStop()
@_silgen_name("MobileIsRunning") private func linkedMobileIsRunning() -> ObjCBool
@_silgen_name("MobileGetPort") private func linkedMobileGetPort() -> Int
#endif

/// Go 后端 MethodChannel 桥接层（iOS）。
///
/// gomobile bind 对包级函数生成的是 **C 函数**（不是 ObjC 类方法）：
///   BOOL MobileStart(NSString* dataDir, NSString* musicDir, long port, long* ret0_, NSError** error);
///   void MobileStop(void);  BOOL MobileIsRunning(void);  long MobileGetPort(void);
/// 其中 MobileStart 返回是否成功，真实端口经 ret0_ 出参返回。
///
/// Songloft.xcframework 是静态 framework，bundled 构建通过可选 xcconfig 将其
/// 链接进 Runner 可执行文件。普通构建未启用 HAS_SONGLOFT_BACKEND 时优雅降级。
class SongloftBackendPlugin: NSObject {
    static let shared = SongloftBackendPlugin()

    // @convention(c) 不允许 ARC 管理类型（NSString/NSError），因此字符串以
    // 原始对象指针传入（gomobile 调用内会同步拷贝，passUnretained 安全），
    // NSError** 传 NULL（gomobile 生成代码对 error 出参有 nil 检查）。
    private typealias StartFn = @convention(c) (
        UnsafeRawPointer?, UnsafeRawPointer?, Int, UnsafeMutablePointer<Int>?, UnsafeMutableRawPointer?
    ) -> ObjCBool
    private typealias StopFn = @convention(c) () -> Void
    private typealias IsRunningFn = @convention(c) () -> ObjCBool
    private typealias GetPortFn = @convention(c) () -> Int

    private var channel: FlutterMethodChannel?

    private let startFn: StartFn?
    private let stopFn: StopFn?
    private let isRunningFn: IsRunningFn?
    private let getPortFn: GetPortFn?

    private override init() {
#if HAS_SONGLOFT_BACKEND
        startFn = linkedMobileStart
        stopFn = linkedMobileStop
        isRunningFn = linkedMobileIsRunning
        getPortFn = linkedMobileGetPort
#else
        startFn = nil
        stopFn = nil
        isRunningFn = nil
        getPortFn = nil
#endif
        super.init()
    }

    func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.songloft/backend", binaryMessenger: messenger)
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    private var isAvailable: Bool {
        startFn != nil && stopFn != nil && isRunningFn != nil && getPortFn != nil
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(isAvailable)
        case "start":
            handleStart(call, result: result)
        case "stop":
            handleStop(result: result)
        case "isRunning":
            result(isRunningFn?().boolValue ?? false)
        case "getPort":
            result(getPortFn?() ?? 0)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleStart(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let dataDir = args["dataDir"] as? String,
              let musicDir = args["musicDir"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "dataDir and musicDir are required", details: nil))
            return
        }
        let port = args["port"] as? Int ?? 0

        guard let startFn = startFn else {
            result(FlutterError(code: "START_FAILED", message: "Go backend framework not bundled", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // 持有 NSString 直到调用返回，保证 passUnretained 指针有效
            let ds = dataDir as NSString
            let ms = musicDir as NSString
            var actualPort = 0
            let ok = startFn(
                Unmanaged.passUnretained(ds).toOpaque(),
                Unmanaged.passUnretained(ms).toOpaque(),
                port,
                &actualPort,
                nil
            ).boolValue
            withExtendedLifetime((ds, ms)) {}
            DispatchQueue.main.async {
                if ok {
                    result(actualPort)
                } else {
                    result(FlutterError(code: "START_FAILED", message: "Go backend failed to start", details: nil))
                }
            }
        }
    }

    private func handleStop(result: @escaping FlutterResult) {
        guard let stopFn = stopFn else {
            result(nil)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            stopFn()
            DispatchQueue.main.async { result(nil) }
        }
    }
}
