package com.songloft.songloft_flutter

import android.app.Application

/**
 * 自定义 Application：在进程最早期（早于任何 gomobile `mobile.*` 类被触碰、早于
 * Flutter 引擎与插件注册）预加载后端热更补丁 `libgojni.so`。
 *
 * 时序是后端热更可行性的根基：必须赶在 gomobile 生成的 `go.Seq` 静态块调用
 * `System.loadLibrary("gojni")` 之前 `System.load(补丁绝对路径)`，靠 bionic 的 soname
 * 去重让后续 loadLibrary 复用补丁版。`SongloftBackendPlugin` 经 MethodChannel 反射调用
 * `mobile.Mobile` 发生在 Dart 请求之后，远晚于此处，故此处足够早。
 *
 * v2 embedding 默认 Application 即 [android.app.Application]（`${applicationName}` 占位符
 * 的默认解析），这里直接继承它并只加一个预加载钩子，不改变其余默认行为。
 */
class SongloftApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        BackendPatchManager.preloadIfStaged(this)
    }
}
