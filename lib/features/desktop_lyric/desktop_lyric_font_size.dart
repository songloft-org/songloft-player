/// 桌面歌词悬浮窗字号档位（songloft-org/songloft#318）
enum DesktopLyricFontSize { small, medium, large }

extension DesktopLyricFontSizeX on DesktopLyricFontSize {
  /// 当前行文字大小
  double get mainTextSize {
    switch (this) {
      case DesktopLyricFontSize.small:
        return 20;
      case DesktopLyricFontSize.medium:
        return 26;
      case DesktopLyricFontSize.large:
        return 34;
    }
  }

  /// 下一行文字大小（比当前行小一档，用于弱化视觉权重）
  double get subTextSize {
    switch (this) {
      case DesktopLyricFontSize.small:
        return 14;
      case DesktopLyricFontSize.medium:
        return 18;
      case DesktopLyricFontSize.large:
        return 22;
    }
  }

  String get storageValue {
    switch (this) {
      case DesktopLyricFontSize.small:
        return 'small';
      case DesktopLyricFontSize.medium:
        return 'medium';
      case DesktopLyricFontSize.large:
        return 'large';
    }
  }

  static DesktopLyricFontSize fromStorageValue(String value) {
    switch (value) {
      case 'small':
        return DesktopLyricFontSize.small;
      case 'large':
        return DesktopLyricFontSize.large;
      case 'medium':
      default:
        return DesktopLyricFontSize.medium;
    }
  }
}
