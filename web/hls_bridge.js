// hls_bridge.js —— hls.js 的薄封装，供 Dart 侧 SongloftWebJustAudioPlugin 调用。
//
// 桌面 Chrome/Edge 的 <audio> 元素原生不支持 HLS(.m3u8)，只有 Safari 支持。
// 本桥接在需要时用 hls.js(MSE) 接管 just_audio_web 创建的 <audio> 元素：
// loadSource + attachMedia 后，hls.js 会把 element.src 设为 MediaSource blob，
// 并驱动标准 media 事件（durationchange/canplay/error 等），
// 因此 just_audio_web 原有的事件监听逻辑无需改动即可继续工作。
//
// 每个 <audio> 元素至多绑定一个 Hls 实例（用 WeakMap 跟踪），换源 / dispose 时销毁，防泄漏。
window.SongloftHls = (function () {
  var instances = new WeakMap(); // HTMLAudioElement -> Hls

  function canUse() {
    return !!(window.Hls && window.Hls.isSupported());
  }

  // attach 用 hls.js 接管 audioElement 播放 url。
  // onError: 可选回调，仅在不可恢复的 fatal 错误时调用一次，参数为错误描述字符串。
  function attach(audioElement, url, onError) {
    if (!canUse()) {
      if (onError) onError('hls.js unavailable');
      return;
    }
    destroy(audioElement);
    try {
      var hls = new window.Hls({ enableWorker: true, lowLatencyMode: false });
      instances.set(audioElement, hls);

      hls.on(window.Hls.Events.ERROR, function (event, data) {
        if (!data || !data.fatal) return;
        // 网络 / 媒体类 fatal 错误先尝试自恢复（直播流常见的临时抖动），成功则不上报。
        try {
          if (data.type === window.Hls.ErrorTypes.NETWORK_ERROR) {
            hls.startLoad();
            return;
          }
          if (data.type === window.Hls.ErrorTypes.MEDIA_ERROR) {
            hls.recoverMediaError();
            return;
          }
        } catch (e) {
          // 恢复失败，继续走下面的销毁 + 上报
        }
        var msg = (data.type || 'hls') + ':' + (data.details || 'fatal');
        destroy(audioElement);
        if (onError) onError(msg);
      });

      hls.loadSource(url);
      hls.attachMedia(audioElement);
    } catch (e) {
      destroy(audioElement);
      if (onError) onError(String(e));
    }
  }

  // destroy 销毁指定元素上的 Hls 实例（若有）。幂等。
  function destroy(audioElement) {
    var hls = instances.get(audioElement);
    if (hls) {
      try {
        hls.destroy();
      } catch (e) {
        // 忽略销毁异常
      }
      instances['delete'](audioElement);
    }
  }

  function isAttached(audioElement) {
    return instances.has(audioElement);
  }

  return {
    canUse: canUse,
    attach: attach,
    destroy: destroy,
    isAttached: isAttached,
  };
})();
