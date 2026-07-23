package com.songloft.songloft_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

/**
 * 内嵌 Go 后端 MethodChannel 桥接层。
 * 通过反射调用 gomobile 生成的 mobile.Mobile 类，这样在 .aar 未打包时
 * 代码依然能编译通过，运行时 isAvailable() 返回 false 即可。
 *
 * 另承载后端热更（换 libgojni.so）的原生方法（stage/getActive/confirm/clear/restart），
 * 这些方法**不依赖** mobile.Mobile 是否存在（补丁落地与进程重启独立于 gomobile），
 * 故在 mobileClass==null 的守卫之前处理。
 */
class SongloftBackendPlugin(private val context: Context, flutterEngine: FlutterEngine) {
    companion object {
        private const val CHANNEL = "com.songloft/backend"

        fun isAvailable(): Boolean {
            return try {
                Class.forName("mobile.Mobile")
                true
            } catch (_: ClassNotFoundException) {
                false
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val mobileClass: Class<*>? = try {
        Class.forName("mobile.Mobile")
    } catch (_: ClassNotFoundException) {
        null
    }

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                // —— 后端热更相关方法（独立于 gomobile，先处理）——
                when (call.method) {
                    "stageBackendPatch" -> {
                        val ok = BackendPatchManager.stage(
                            context,
                            call.argument("soPath") ?: "",
                            call.argument("patchLabel") ?: "",
                            call.argument("version") ?: "",
                            call.argument("gitCommit") ?: "",
                            call.argument("md5") ?: ""
                        )
                        result.success(ok)
                        return@setMethodCallHandler
                    }
                    "getActiveBackendPatch" -> {
                        result.success(BackendPatchManager.getActive(context))
                        return@setMethodCallHandler
                    }
                    "confirmBackendPatch" -> {
                        BackendPatchManager.confirm(context)
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    "clearBackendPatch" -> {
                        BackendPatchManager.clear(context)
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    "restartProcess" -> {
                        result.success(null)
                        // 延迟到当前调用返回后再杀进程，确保 result 已回传 Dart。
                        mainHandler.post { ProcessRestarter.restart(context) }
                        return@setMethodCallHandler
                    }
                }

                if (mobileClass == null) {
                    result.error("NOT_AVAILABLE", "Go backend .aar not bundled", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "start" -> handleStart(call.argument("dataDir"), call.argument("musicDir"), call.argument("port") ?: 0, result)
                    "stop" -> handleStop(result)
                    "isRunning" -> handleIsRunning(result)
                    "getPort" -> handleGetPort(result)
                    "isAvailable" -> result.success(true)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleStart(dataDir: String?, musicDir: String?, port: Int, result: MethodChannel.Result) {
        if (dataDir == null || musicDir == null) {
            result.error("INVALID_ARG", "dataDir and musicDir are required", null)
            return
        }
        thread {
            try {
                val startMethod = mobileClass!!.getMethod("start", String::class.java, String::class.java, Long::class.javaPrimitiveType)
                val actualPort = startMethod.invoke(null, dataDir, musicDir, port.toLong()) as Long
                mainHandler.post { result.success(actualPort.toInt()) }
            } catch (e: Exception) {
                val cause = e.cause ?: e
                mainHandler.post { result.error("START_FAILED", cause.message, null) }
            }
        }
    }

    private fun handleStop(result: MethodChannel.Result) {
        thread {
            try {
                val stopMethod = mobileClass!!.getMethod("stop")
                stopMethod.invoke(null)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("STOP_FAILED", e.message, null) }
            }
        }
    }

    private fun handleIsRunning(result: MethodChannel.Result) {
        try {
            val method = mobileClass!!.getMethod("isRunning")
            result.success(method.invoke(null) as Boolean)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun handleGetPort(result: MethodChannel.Result) {
        try {
            val method = mobileClass!!.getMethod("getPort")
            val port = method.invoke(null) as Long
            result.success(port.toInt())
        } catch (e: Exception) {
            result.success(0)
        }
    }
}
