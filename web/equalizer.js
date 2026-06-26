window.SongloftEqualizer = (function () {
  var ctx = null;
  var filters = [];
  var sourceNode = null;
  var attachedElement = null;
  var enabled = false;
  var bypassGain = null;
  var filterGain = null;

  var FREQUENCIES = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

  function init() {
    if (ctx) return;
    ctx = new (window.AudioContext || window.webkitAudioContext)();

    bypassGain = ctx.createGain();
    filterGain = ctx.createGain();

    for (var i = 0; i < FREQUENCIES.length; i++) {
      var filter = ctx.createBiquadFilter();
      filter.type = i === 0 ? 'lowshelf' : i === FREQUENCIES.length - 1 ? 'highshelf' : 'peaking';
      filter.frequency.value = FREQUENCIES[i];
      if (filter.type === 'peaking') {
        filter.Q.value = 1.4;
      }
      filter.gain.value = 0;
      filters.push(filter);
    }

    for (var i = 0; i < filters.length - 1; i++) {
      filters[i].connect(filters[i + 1]);
    }
    filters[filters.length - 1].connect(filterGain);
    filterGain.connect(ctx.destination);
    bypassGain.connect(ctx.destination);
  }

  function attach(audioElement) {
    if (!ctx) return;
    if (audioElement === attachedElement) return;

    if (ctx.state === 'suspended') {
      ctx.resume();
    }

    if (sourceNode) {
      sourceNode.disconnect();
      sourceNode = null;
    }

    try {
      sourceNode = ctx.createMediaElementSource(audioElement);
      attachedElement = audioElement;
      _updateRouting();
    } catch (e) {
      if (e.name === 'InvalidStateError' && attachedElement === audioElement) {
        _updateRouting();
      } else {
        console.warn('[EQ] Failed to attach audio element:', e);
      }
    }
  }

  function setEnabled(value) {
    enabled = value;
    _updateRouting();
  }

  function setBands(gains) {
    for (var i = 0; i < gains.length && i < filters.length; i++) {
      filters[i].gain.value = gains[i];
    }
  }

  function setGain(bandIndex, gainDB) {
    if (bandIndex >= 0 && bandIndex < filters.length) {
      filters[bandIndex].gain.value = gainDB;
    }
  }

  function isInitialized() {
    return ctx !== null;
  }

  function _updateRouting() {
    if (!sourceNode) return;
    sourceNode.disconnect();
    if (enabled) {
      sourceNode.connect(filters[0]);
    } else {
      sourceNode.connect(bypassGain);
    }
  }

  return {
    init: init,
    attach: attach,
    setEnabled: setEnabled,
    setBands: setBands,
    setGain: setGain,
    isInitialized: isInitialized,
  };
})();
