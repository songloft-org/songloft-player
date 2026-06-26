import Foundation
import Flutter

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Live Activity 管理器
/// 负责灵动岛/锁屏 Live Activity 的生命周期管理
class LiveActivityManager: NSObject {
    static let shared = LiveActivityManager()

    private var channelName = "com.songloft.songloftFlutter/liveActivity"
    private var channel: FlutterMethodChannel?

    #if canImport(ActivityKit)
    private var currentActivity: Any? // Activity<SongloftMusicAttributes>
    #endif

    private override init() {
        super.init()
    }

    /// 注册 MethodChannel
    func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(isSupported())
        case "startActivity":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
                return
            }
            startActivity(
                title: args["title"] as? String ?? "",
                artist: args["artist"] as? String ?? "",
                lyricLine: args["lyricLine"] as? String ?? "",
                artUrl: args["artUrl"] as? String ?? ""
            )
            result(nil)
        case "updateLyric":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
                return
            }
            updateLyric(
                lyricLine: args["lyricLine"] as? String ?? "",
                nextLine: args["nextLine"] as? String ?? ""
            )
            result(nil)
        case "updatePlaybackState":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
                return
            }
            updatePlaybackState(
                isPlaying: args["isPlaying"] as? Bool ?? false,
                progress: args["progress"] as? Double ?? 0.0
            )
            result(nil)
        case "endActivity":
            endActivity()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Public API

    func isSupported() -> Bool {
        if #available(iOS 16.2, *) {
            #if canImport(ActivityKit)
            let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
            if !enabled {
                print("[LiveActivity] areActivitiesEnabled = false (check Settings > Songloft > Live Activities)")
            }
            return enabled
            #else
            print("[LiveActivity] ActivityKit not available in this build")
            return false
            #endif
        }
        print("[LiveActivity] iOS version < 16.2, Live Activity not supported")
        return false
    }

    func startActivity(title: String, artist: String, lyricLine: String, artUrl: String) {
        guard isSupported() else { return }

        if #available(iOS 16.2, *) {
            #if canImport(ActivityKit)
            endActivityInternal()

            let attributes = SongloftMusicAttributes(
                songTitle: title,
                artist: artist
            )
            let state = SongloftMusicAttributes.ContentState(
                lyricLine: lyricLine,
                nextLyricLine: "",
                isPlaying: true,
                progress: 0.0
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: nil),
                    pushType: nil
                )
                currentActivity = activity
                print("[LiveActivity] Activity started: id=\(activity.id), title=\(title)")
            } catch {
                print("[LiveActivity] Failed to start activity: \(error)")
            }
            #endif
        }
    }

    func updateLyric(lyricLine: String, nextLine: String) {
        guard isSupported() else { return }

        if #available(iOS 16.2, *) {
            #if canImport(ActivityKit)
            guard let activity = currentActivity as? Activity<SongloftMusicAttributes> else { return }

            let currentState = activity.content.state
            let newState = SongloftMusicAttributes.ContentState(
                lyricLine: lyricLine,
                nextLyricLine: nextLine,
                isPlaying: currentState.isPlaying,
                progress: currentState.progress
            )

            Task {
                await activity.update(ActivityContent(state: newState, staleDate: nil))
            }
            #endif
        }
    }

    func updatePlaybackState(isPlaying: Bool, progress: Double) {
        guard isSupported() else { return }

        if #available(iOS 16.2, *) {
            #if canImport(ActivityKit)
            guard let activity = currentActivity as? Activity<SongloftMusicAttributes> else { return }

            let currentState = activity.content.state
            let newState = SongloftMusicAttributes.ContentState(
                lyricLine: currentState.lyricLine,
                nextLyricLine: currentState.nextLyricLine,
                isPlaying: isPlaying,
                progress: progress
            )

            Task {
                await activity.update(ActivityContent(state: newState, staleDate: nil))
            }
            #endif
        }
    }

    func endActivity() {
        if #available(iOS 16.2, *) {
            #if canImport(ActivityKit)
            endActivityInternal()
            #endif
        }
    }

    // MARK: - Private

    @available(iOS 16.2, *)
    private func endActivityInternal() {
        #if canImport(ActivityKit)
        guard let activity = currentActivity as? Activity<SongloftMusicAttributes> else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        #endif
    }
}
