import Flutter

/// Go 后端 MethodChannel 桥接层（iOS）。
/// 通过反射调用 gomobile 生成的 Mobile framework 中的函数，
/// .xcframework 未打包时 isAvailable 返回 false，不会崩溃。
class SongloftBackendPlugin: NSObject {
    static let shared = SongloftBackendPlugin()

    private var channel: FlutterMethodChannel?
    private let mobileClass: AnyClass? = NSClassFromString("MobileMobile")

    private override init() {
        super.init()
    }

    func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.songloft/backend", binaryMessenger: messenger)
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(mobileClass != nil)
        case "start":
            handleStart(call, result: result)
        case "stop":
            handleStop(result: result)
        case "isRunning":
            handleIsRunning(result: result)
        case "getPort":
            handleGetPort(result: result)
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

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let actualPort = try self.callStart(dataDir: dataDir, musicDir: musicDir, port: port)
                DispatchQueue.main.async { result(actualPort) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func handleStop(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.callStop()
            DispatchQueue.main.async { result(nil) }
        }
    }

    private func handleIsRunning(result: FlutterResult) {
        result(callIsRunning())
    }

    private func handleGetPort(result: FlutterResult) {
        result(callGetPort())
    }

    // MARK: - gomobile 反射调用

    private func callStart(dataDir: String, musicDir: String, port: Int) throws -> Int {
        // gomobile 生成的 ObjC 函数：MobileStart(dataDir, musicDir, port, &error)
        let selector = NSSelectorFromString("startWithDataDir:musicDir:port:error:")
        guard let cls = mobileClass, cls.responds(to: selector) else {
            throw NSError(domain: "SongloftBackend", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Go backend .xcframework not bundled"])
        }
        // 使用 NSInvocation 进行反射调用
        let method = cls.method(for: selector)
        typealias StartFunc = @convention(c) (AnyClass, Selector, String, String, Int, UnsafeMutablePointer<NSError?>) -> Int
        let impl = unsafeBitCast(method, to: StartFunc.self)
        var error: NSError?
        let actualPort = impl(cls, selector, dataDir, musicDir, port, &error)
        if let error = error { throw error }
        return actualPort
    }

    private func callStop() {
        let selector = NSSelectorFromString("stop")
        if let cls = mobileClass, cls.responds(to: selector) {
            _ = cls.perform(selector)
        }
    }

    private func callIsRunning() -> Bool {
        let selector = NSSelectorFromString("isRunning")
        guard let cls = mobileClass, cls.responds(to: selector) else { return false }
        // gomobile 布尔返回通过 perform 不太方便，用安全默认值
        let result = cls.perform(selector)
        return result != nil
    }

    private func callGetPort() -> Int {
        let selector = NSSelectorFromString("getPort")
        guard let cls = mobileClass, cls.responds(to: selector) else { return 0 }
        // gomobile int 返回
        let result = cls.perform(selector)
        return Int(bitPattern: result?.toOpaque() ?? UnsafeMutableRawPointer(bitPattern: 0))
    }
}
