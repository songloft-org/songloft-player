class EqualizerSetting {
  final bool enabled;
  final String preset;
  final List<double> bands;

  const EqualizerSetting({
    required this.enabled,
    required this.preset,
    required this.bands,
  });

  factory EqualizerSetting.defaults() => const EqualizerSetting(
    enabled: false,
    preset: 'flat',
    bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  factory EqualizerSetting.fromJson(Map<String, dynamic> json) {
    return EqualizerSetting(
      enabled: json['enabled'] as bool? ?? false,
      preset: json['preset'] as String? ?? 'flat',
      bands:
          (json['bands'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          List.filled(bandCount, 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'preset': preset,
    'bands': bands,
  };

  EqualizerSetting copyWith({
    bool? enabled,
    String? preset,
    List<double>? bands,
  }) => EqualizerSetting(
    enabled: enabled ?? this.enabled,
    preset: preset ?? this.preset,
    bands: bands ?? this.bands,
  );

  static const int bandCount = 10;

  static const List<int> frequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  static String frequencyLabel(int index) {
    final freq = frequencies[index];
    return freq >= 1000 ? '${freq ~/ 1000}k' : '$freq';
  }

  static const double minGain = -12.0;
  static const double maxGain = 12.0;

  static const Map<String, List<double>> presets = {
    'flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'rock': [5, 4, 2, 0, -1, 1, 3, 4, 5, 4],
    'pop': [-1, 2, 4, 5, 4, 2, 0, -1, -1, -1],
    'jazz': [4, 3, 1, 2, -1, -1, 0, 2, 3, 4],
    'classical': [5, 4, 3, 2, -1, -1, 0, 3, 4, 5],
    'bass_boost': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
    'treble_boost': [0, 0, 0, 0, 0, 0, 2, 4, 5, 6],
    'vocal': [-2, -1, 0, 3, 5, 5, 3, 1, 0, -2],
  };

  /// 预设显示顺序（内部 key，用于持久化；显示名由 UI 层通过 l10n 映射）
  static const List<String> presetOrder = [
    'flat',
    'rock',
    'pop',
    'jazz',
    'classical',
    'bass_boost',
    'treble_boost',
    'vocal',
    'custom',
  ];
}
