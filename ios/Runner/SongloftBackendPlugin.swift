import Flutter
import Foundation

/// Go 后端 MethodChannel 桥接层（iOS）。
///
/// gomobile bind 对包级函数生成的是 **C 函数**（不是 ObjC 类方法）：
///   BOOL MobileStart(NSString* dataDir, NSString* musicDir, long port, long* ret0_, NSError** error);
///   void MobileStop(void);  BOOL MobileIsRunning(void);  long MobileGetPort(void);
/// 其中 MobileStart 返回是否成功，真实端口经 ret0_ 出参返回。
///
/// Songloft.xcframework 由构建期的 Run Script 可选地嵌入 Runner.app/Frameworks/，
/// 这里用 dlopen 打开、dlsym 取符号；框架未嵌入（非 bundled 构建）时
/// dlopen 返回 nil，isAvailable 为 false，本地模式优雅降级不可用。
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
        // 打开嵌入的 Go 后端框架：Runner.app/Frameworks/Songloft.framework/Songloft
        var handle: UnsafeMutableRawPointer?
        if let fwDir = Bundle.main.privateFrameworksPath {
            let binPath = (fwDir as NSString).appendingPathComponent("Songloft.framework/Songloft")
            handle = dlopen(binPath, RTLD_NOW)
        }

        func load<T>(_ name: String, _ type: T.Type) -> T? {
            guard let handle = handle, let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: type)
        }

        startFn = load("MobileStart", StartFn.self)
        stopFn = load("MobileStop", StopFn.self)
        isRunningFn = load("MobileIsRunning", IsRunningFn.self)
        getPortFn = load("MobileGetPort", GetPortFn.self)
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
