import FlutterMacOS
import AVFoundation

@_silgen_name("SongloftGetJustAudioPlugin")
func SongloftGetJustAudioPlugin() -> NSObject?

class EqualizerPlugin: NSObject {
    static let shared = EqualizerPlugin()

    private var channel: FlutterMethodChannel?
    private var audioEngine: AVAudioEngine?
    private var eqNode: AVAudioUnitEQ?
    private var isAttached = false

    private let frequencies: [Float] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    private override init() {
        super.init()
    }

    func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.songloft.equalizer", binaryMessenger: messenger)
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            result(initialize())
        case "apply":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
                return
            }
            apply(args: args)
            result(nil)
        case "setEnabled":
            guard let args = call.arguments as? [String: Any],
                  let enabled = args["enabled"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "enabled required", details: nil))
                return
            }
            setEnabled(enabled)
            result(nil)
        case "setBandGain":
            guard let args = call.arguments as? [String: Any],
                  let index = args["index"] as? Int,
                  let gain = args["gain"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "index and gain required", details: nil))
                return
            }
            setBandGain(index: index, gain: Float(gain))
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize() -> Bool {
        // macOS 上 just_audio 默认不走 AVPlayer（走 media_kit/mpv），
        // 所以 Darwin EQ 在 macOS 上通常不适用。
        // 如果用户配置了 macOS 走 AVPlayer，则需要 macOS 12.0+。
        guard #available(macOS 12.0, *) else { return false }
        return setupEQ()
    }

    @available(macOS 12.0, *)
    private func setupEQ() -> Bool {
        guard !isAttached else { return true }

        guard let avPlayer = findAVPlayer() else {
            print("[EQ-Darwin] AVPlayer not found yet, will retry on apply")
            return true
        }

        return attachToPlayer(avPlayer)
    }

    @available(macOS 12.0, *)
    private func attachToPlayer(_ avPlayer: AVQueuePlayer) -> Bool {
        guard !isAttached else { return true }

        let engine = AVAudioEngine()
        let eq = AVAudioUnitEQ(numberOfBands: UInt32(frequencies.count))

        for (i, freq) in frequencies.enumerated() {
            let band = eq.bands[i]
            band.filterType = .parametric
            band.frequency = freq
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false
        }

        engine.attach(eq)

        let outputNode = avPlayer.audioOutputNode
        let mainMixer = engine.mainMixerNode
        let format = outputNode.outputFormat(forBus: 0)

        engine.connect(outputNode, to: eq, format: format)
        engine.connect(eq, to: mainMixer, format: format)

        do {
            try engine.start()
            audioEngine = engine
            eqNode = eq
            isAttached = true
            print("[EQ-Darwin] Audio engine started with EQ")
            return true
        } catch {
            print("[EQ-Darwin] Failed to start audio engine: \(error)")
            return false
        }
    }

    private func findAVPlayer() -> AVQueuePlayer? {
        guard let plugin = SongloftGetJustAudioPlugin() else {
            print("[EQ-Darwin] JustAudioPlugin not captured")
            return nil
        }

        guard let players = plugin.value(forKey: "_players") as? NSDictionary else {
            print("[EQ-Darwin] Could not access _players via KVC")
            return nil
        }

        for (_, audioPlayer) in players {
            if let ap = audioPlayer as? NSObject,
               ap.responds(to: NSSelectorFromString("player")),
               let avPlayer = ap.value(forKey: "player") as? AVQueuePlayer {
                return avPlayer
            }
        }

        print("[EQ-Darwin] No AudioPlayer with AVPlayer found")
        return nil
    }

    private func apply(args: [String: Any]) {
        let enabled = args["enabled"] as? Bool ?? false
        let bands = args["bands"] as? [Double] ?? []

        if #available(macOS 12.0, *) {
            if !isAttached, let avPlayer = findAVPlayer() {
                _ = attachToPlayer(avPlayer)
            }
        }

        guard let eq = eqNode else { return }

        eq.bypass = !enabled

        for (i, gain) in bands.enumerated() {
            guard i < eq.bands.count else { break }
            eq.bands[i].gain = Float(gain)
        }
    }

    private func setEnabled(_ enabled: Bool) {
        eqNode?.bypass = !enabled
    }

    private func setBandGain(index: Int, gain: Float) {
        guard let eq = eqNode, index < eq.bands.count else { return }
        eq.bands[index].gain = gain
    }
}
