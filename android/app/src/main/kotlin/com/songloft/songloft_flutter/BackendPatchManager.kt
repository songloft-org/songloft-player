package com.songloft.songloft_flutter

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Bundle 版 Android 后端热更（替换 gomobile 的 `libgojni.so`）的原生真相源。
 *
 * 机制（见 songloft-player/docs/cn/backend_hotupdate.md）：
 * - 补丁 .so 落在应用私有目录 `filesDir/backend_patch/active/libgojni.so`；
 * - 状态存**纯文件** `filesDir/backend_patch/state.json`（不用 flutter 的
 *   shared_preferences —— 需在 Dart 引擎起来前、[SongloftApplication.onCreate] 里读）；
 * - [preloadIfStaged] 在进程最早期（任何 gomobile `mobile.*` 类被触碰前）用
 *   `System.load(补丁绝对路径)` 预加载补丁版；bionic 按 ELF soname `libgojni.so` 去重，
 *   之后 gomobile 的 `System.loadLibrary("gojni")` 复用补丁版，不再加载 APK 随包旧版；
 * - 崩溃回滚：pending→confirmed 状态机 + bootAttempts 计数 + 黑名单。加载失败或启动即
 *   崩时拉黑该补丁并回滚随包版，且不再重复下发（见 [getActive]）。
 *
 * 所有方法自带 try/catch，任何异常都不得让宿主进程崩溃。
 */
object BackendPatchManager {
    private const val TAG = "BackendPatch"
    private const val DIR = "backend_patch"
    private const val ACTIVE_DIR = "active"
    private const val SO_NAME = "libgojni.so"
    private const val STATE_FILE = "state.json"

    /** 允许的未确认启动次数上限；超过即判定「启动即崩」→ 回滚 + 拉黑（fail-fast，容 1 次）。 */
    private const val MAX_BOOT_ATTEMPTS = 1

    private const val STATE_STAGED = "staged"
    private const val STATE_PENDING = "pending"
    private const val STATE_CONFIRMED = "confirmed"

    private fun baseDir(ctx: Context): File = File(ctx.filesDir, DIR)
    private fun activeSo(ctx: Context): File = File(File(baseDir(ctx), ACTIVE_DIR), SO_NAME)
    private fun stateFile(ctx: Context): File = File(baseDir(ctx), STATE_FILE)

    @Synchronized
    private fun readState(ctx: Context): JSONObject {
        return try {
            val f = stateFile(ctx)
            if (!f.exists()) JSONObject() else JSONObject(f.readText())
        } catch (t: Throwable) {
            Log.w(TAG, "readState 失败，视为空状态: ${t.message}")
            JSONObject()
        }
    }

    @Synchronized
    private fun writeState(ctx: Context, state: JSONObject) {
        try {
            val dir = baseDir(ctx)
            if (!dir.exists()) dir.mkdirs()
            stateFile(ctx).writeText(state.toString())
        } catch (t: Throwable) {
            Log.e(TAG, "writeState 失败: ${t.message}")
        }
    }

    private fun blacklistKey(gitCommit: String, md5: String): String = "$gitCommit:$md5"

    private fun isBlacklisted(state: JSONObject, key: String): Boolean {
        val arr = state.optJSONArray("blacklist") ?: return false
        for (i in 0 until arr.length()) {
            if (arr.optString(i) == key) return true
        }
        return false
    }

    private fun addBlacklist(state: JSONObject, key: String) {
        val arr = state.optJSONArray("blacklist") ?: JSONArray()
        arr.put(key)
        state.put("blacklist", arr)
    }

    /**
     * 进程最早期调用（[SongloftApplication.onCreate]）。若存在有效的待生效/已生效补丁，
     * `System.load` 预加载之；否则不加载（后续 gomobile 自动用 APK 随包 .so = 回滚）。
     */
    @Synchronized
    fun preloadIfStaged(ctx: Context) {
        try {
            val state = readState(ctx)
            val active = state.optJSONObject("active") ?: return

            val gitCommit = active.optString("gitCommit")
            val md5 = active.optString("md5")
            val key = blacklistKey(gitCommit, md5)
            if (isBlacklisted(state, key)) {
                Log.w(TAG, "补丁在黑名单，回滚随包版: $key")
                return
            }

            val so = activeSo(ctx)
            if (!so.exists()) {
                Log.w(TAG, "补丁 .so 不存在，清理: ${so.path}")
                state.remove("active")
                writeState(ctx, state)
                return
            }

            val stateStr = active.optString("state", STATE_STAGED)
            if (stateStr != STATE_CONFIRMED) {
                val attempts = state.optInt("bootAttempts", 0) + 1
                if (attempts > MAX_BOOT_ATTEMPTS) {
                    // 未确认就再次启动 → 判定启动即崩 → 拉黑 + 回滚。
                    Log.w(TAG, "补丁启动即崩（attempts=$attempts），拉黑回滚: $key")
                    addBlacklist(state, key)
                    state.remove("active")
                    state.put("bootAttempts", 0)
                    writeState(ctx, state)
                    return
                }
                state.put("bootAttempts", attempts)
                active.put("state", STATE_PENDING)
                writeState(ctx, state)
            }

            // 预加载补丁 .so。失败（ELF/ABI/soname 坏）→ 立即拉黑 + 回滚，绝不让进程崩。
            try {
                System.load(so.absolutePath)
                Log.i(TAG, "已预加载后端补丁: ${so.absolutePath} (state=$stateStr)")
            } catch (t: Throwable) {
                Log.e(TAG, "System.load 失败，拉黑回滚: ${t.message}")
                addBlacklist(state, key)
                state.remove("active")
                state.put("bootAttempts", 0)
                writeState(ctx, state)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "preloadIfStaged 异常（忽略）: ${t.message}")
        }
    }

    /**
     * 落地一个已下载 + md5 校验过的补丁 .so 为「待生效」。做原子搬移（rename 失败回退
     * copy）+ 重置 bootAttempts。返回是否成功。
     */
    @Synchronized
    fun stage(
        ctx: Context,
        soPath: String,
        patchLabel: String,
        version: String,
        gitCommit: String,
        md5: String
    ): Boolean {
        return try {
            val src = File(soPath)
            if (!src.exists()) {
                Log.e(TAG, "stage: 源文件不存在 $soPath")
                return false
            }
            val dest = activeSo(ctx)
            dest.parentFile?.mkdirs()
            if (dest.exists()) dest.delete()

            // 优先 rename（同文件系统原子）；失败回退 copy + delete。
            if (!src.renameTo(dest)) {
                src.copyTo(dest, overwrite = true)
                src.delete()
            }

            val state = readState(ctx)
            val active = JSONObject()
                .put("path", dest.absolutePath)
                .put("patchLabel", patchLabel)
                .put("version", version)
                .put("gitCommit", gitCommit)
                .put("md5", md5)
                .put("state", STATE_STAGED)
            state.put("active", active)
            state.put("bootAttempts", 0)
            writeState(ctx, state)
            Log.i(TAG, "已 stage 后端补丁: $patchLabel ($gitCommit)")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "stage 失败: ${t.message}")
            false
        }
    }

    /** 确认当前补丁启动健康：state→confirmed，bootAttempts 清零。 */
    @Synchronized
    fun confirm(ctx: Context) {
        try {
            val state = readState(ctx)
            val active = state.optJSONObject("active") ?: return
            active.put("state", STATE_CONFIRMED)
            state.put("bootAttempts", 0)
            writeState(ctx, state)
            Log.i(TAG, "后端补丁已确认: ${active.optString("patchLabel")}")
        } catch (t: Throwable) {
            Log.e(TAG, "confirm 失败: ${t.message}")
        }
    }

    /** 清除当前待生效补丁（回滚随包版）；不拉黑。 */
    @Synchronized
    fun clear(ctx: Context) {
        try {
            val state = readState(ctx)
            state.remove("active")
            state.put("bootAttempts", 0)
            writeState(ctx, state)
            val dir = File(baseDir(ctx), ACTIVE_DIR)
            if (dir.exists()) dir.deleteRecursively()
        } catch (t: Throwable) {
            Log.e(TAG, "clear 失败: ${t.message}")
        }
    }

    /** 返回当前 active 补丁的 {patchLabel, version, gitCommit, md5, state}，无则 null。 */
    @Synchronized
    fun getActive(ctx: Context): Map<String, Any?>? {
        return try {
            val active = readState(ctx).optJSONObject("active") ?: return null
            mapOf(
                "patchLabel" to active.optString("patchLabel"),
                "version" to active.optString("version"),
                "gitCommit" to active.optString("gitCommit"),
                "md5" to active.optString("md5"),
                "state" to active.optString("state")
            )
        } catch (t: Throwable) {
            null
        }
    }
}
