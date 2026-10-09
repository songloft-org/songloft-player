package com.songloft.songloft_flutter

import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var cacheStorage: SongCacheStorage? = null

    companion object {
        // 原生契约哈希闸（见 docs/cn/backend_hotupdate.md「原生契约哈希闸」）。
        // asset 由 CI 用 scripts/compute_native_contract.sh 在打包前生成，内容形如
        // {"dart":"<sha>","go":"<sha>"}。热更客户端运行时读它与 manifest 比对，
        // 不等即拒绝热更（落整包）。本地开发无此 asset → 返回空串 → 客户端降级不拦截。
        private const val CONTRACT_CHANNEL = "com.songloft/contract"
        private const val CONTRACT_ASSET = "native_contract.json"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 原生契约哈希：读打包进 APK 的 asset 原文返回（缺失/异常 → 空串，客户端降级不拦截）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTRACT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getHash") {
                    val json =
                        try {
                            applicationContext.assets
                                .open(CONTRACT_ASSET)
                                .bufferedReader()
                                .use { it.readText() }
                                .trim()
                        } catch (e: Exception) {
                            ""
                        }
                    result.success(json)
                } else {
                    result.notImplemented()
                }
            }

        // 注册内嵌后端 MethodChannel（反射调用 .aar，未打包时自动降级）
        SongloftBackendPlugin(applicationContext, flutterEngine)

        // 悬浮歌词窗口（songloft-org/songloft#318）
        val storage = SongCacheStorage(this)
        cacheStorage = storage
        FloatingLyricPlugin(applicationContext, flutterEngine, storage)

        // 注册桌面小部件 MethodChannel
        WidgetActionPlugin(applicationContext, flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (cacheStorage?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        cacheStorage?.dispose()
        cacheStorage = null
        super.onDestroy()
    }
}
