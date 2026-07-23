package com.songloft.songloft_flutter

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.os.Process
import android.util.Log

/**
 * 冷重启整个进程：预约拉起 MainActivity 的 PendingIntent，随后杀掉当前进程。
 *
 * 后端热更换 `libgojni.so` 必须真正的进程冷启才生效（Go runtime 单进程只初始化一次，
 * dlclose 不可靠）。Flutter 的 `SystemNavigator.pop()` 只 finish Activity、进程常保活，
 * 不会重跑 [SongloftApplication.onCreate] 的预加载，故不可用。这里用 AlarmManager 定时
 * 拉起 + `Process.killProcess` 强杀，新进程走 onCreate 预加载补丁。
 */
object ProcessRestarter {
    private const val TAG = "BackendPatch"

    fun restart(ctx: Context) {
        try {
            val context = ctx.applicationContext
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent == null) {
                Log.e(TAG, "restart: 无法获取 launch intent")
                return
            }
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK)

            var flags = PendingIntent.FLAG_ONE_SHOT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            val pending = PendingIntent.getActivity(context, 0, intent, flags)

            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.setExact(
                AlarmManager.RTC,
                System.currentTimeMillis() + 400,
                pending
            )
        } catch (t: Throwable) {
            Log.e(TAG, "restart 预约失败（仍将杀进程）: ${t.message}")
        } finally {
            // 杀掉当前进程；系统在 400ms 后按上面的 alarm 拉起新进程。
            Process.killProcess(Process.myPid())
            Runtime.getRuntime().exit(0)
        }
    }
}
