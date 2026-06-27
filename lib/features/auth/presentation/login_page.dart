import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/app_config.dart';
import '../../../core/backend/embedded_backend_service.dart';
import '../../../core/backend/run_mode_provider.dart';
import '../../../core/network/base_url_provider.dart';
import '../../../core/network/server_entry.dart';
import '../../../core/network/servers_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/tv_theme.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../domain/auth_state.dart';
import 'providers/auth_provider.dart';

/// 登录页面
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiUrlController = TextEditingController();

  // TV 焦点节点
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _apiUrlFocusNode = FocusNode();
  final _loginButtonFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isLocalModeBootstrapping = false;
  String _localModeHint = '';

  // TV 焦点步骤指示器
  int _currentStep = 1;
  int get _totalSteps => !AppConfig.isEmbedded ? 3 : 2;

  bool get _isApiUrlVisible => !AppConfig.isEmbedded;

  @override
  void initState() {
    super.initState();
    // 嵌入模式下 API 地址已由 main() 设定，无需加载存储的地址
    if (!AppConfig.isEmbedded) {
      _loadSavedApiUrl();
    }
    _loadSavedCredentials();

    // 本地模式下自动登录（token 过期回到登录页时，无需用户手动操作）
    if (_showLocalMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLoginLocal());
    }

    // 监听焦点变化更新步骤指示器
    _usernameFocusNode.addListener(_updateStep);
    _passwordFocusNode.addListener(_updateStep);
    _apiUrlFocusNode.addListener(_updateStep);
  }

  void _updateStep() {
    int newStep = _currentStep;
    if (_usernameFocusNode.hasFocus) {
      newStep = 1;
    } else if (_passwordFocusNode.hasFocus) {
      newStep = 2;
    } else if (_apiUrlFocusNode.hasFocus) {
      newStep = 3;
    }
    if (newStep != _currentStep) {
      setState(() {
        _currentStep = newStep;
      });
    }
  }

  Future<void> _loadSavedApiUrl() async {
    // 列表 1 项时预填该项的 url（与单地址旧版体验一致）。
    // 列表 ≥ 2 项时输入框被替换为下拉，无需预填。
    try {
      final servers = await ref.read(serversProvider.future);
      if (servers.length == 1 && servers.first.url.isNotEmpty) {
        _apiUrlController.text = servers.first.url;
      }
    } catch (_) {
      // 忽略
    }
  }

  Future<void> _loadSavedCredentials() async {
    // 优先从当前服务器的 ServerEntry 读取保存的凭证
    try {
      final currentUrl = ref.read(baseUrlProvider);
      final servers = await ref.read(serversProvider.future);
      final entry = servers.where((e) => e.url == currentUrl).firstOrNull;
      if (entry != null && entry.username != null && entry.username!.isNotEmpty) {
        _usernameController.text = entry.username!;
        if (entry.password != null) _passwordController.text = entry.password!;
        return;
      }
    } catch (_) {}
    // 兼容回退：全局 last 凭证
    final prefs = await ref.read(appPreferencesProvider.future);
    final savedUsername = prefs.getLastUsername();
    final savedPassword = prefs.getLastPassword();
    if (savedUsername != null && savedUsername.isNotEmpty) {
      _usernameController.text = savedUsername;
    }
    if (savedPassword != null && savedPassword.isNotEmpty) {
      _passwordController.text = savedPassword;
    }
  }

  @override
  void dispose() {
    _usernameFocusNode.removeListener(_updateStep);
    _passwordFocusNode.removeListener(_updateStep);
    _apiUrlFocusNode.removeListener(_updateStep);
    _usernameController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _apiUrlFocusNode.dispose();
    _loginButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authNotifier = ref.read(authStateProvider.notifier);

    String? apiBaseUrl;
    if (!AppConfig.isEmbedded) {
      final servers = ref.read(serversProvider).value ?? const <ServerEntry>[];
      if (servers.length >= 2) {
        // 多服务器：默认布局走 dropdown，TV 布局也以 baseUrlProvider 为准
        apiBaseUrl = ref.read(baseUrlProvider);
      } else {
        // 0/1 项：使用单输入框的值
        final raw = _apiUrlController.text.trim();
        if (raw.isNotEmpty) {
          apiBaseUrl = raw.replaceAll(RegExp(r'/+$'), '');
        }
      }
    }

    await authNotifier.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      apiBaseUrl: apiBaseUrl,
    );
  }

  /// 判断是否为 TV 端（屏幕宽度 >= 1920）
  bool _isTv(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1920;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 监听认证状态变化，显示错误信息
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ResponsiveSnackBar.showError(context, message: next.error!);
      }

      // 登录成功后跳转到首页
      if (next.status == AuthStatus.authenticated) {
        context.go(AppRoutes.home);
      }
    });

    // 本地模式自动登录中，显示加载界面
    if (_isLocalModeBootstrapping &&
        ref.read(runModeProvider) == RunMode.local) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/app_icon.png',
                width: 64,
                height: 64,
                semanticLabel: 'Songloft',
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(_localModeHint),
            ],
          ),
        ),
      );
    }

    if (_isTv(context)) {
      return _buildTvLayout(context, authState, theme, colorScheme);
    }

    return _buildDefaultLayout(context, authState, theme, colorScheme);
  }

  // ========== 默认布局（手机/平板/桌面）==========

  Widget _buildDefaultLayout(
    BuildContext context,
    AuthState authState,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo 和标题
                    _buildHeader(theme, colorScheme),
                    const SizedBox(height: 48),

                    // 登录表单卡片
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 用户名输入框
                            _buildUsernameField(colorScheme),
                            const SizedBox(height: 16),

                            // 密码输入框
                            _buildPasswordField(colorScheme),
                            const SizedBox(height: 16),

                            // API 地址输入框 — 嵌入模式下隐藏，独立部署时显示
                            if (!AppConfig.isEmbedded)
                              _buildApiUrlField(colorScheme),
                            const SizedBox(height: 24),

                            // 登录按钮
                            _buildLoginButton(authState, colorScheme),
                          ],
                        ),
                      ),
                    ),

                    if (_showLocalMode) ...[
                      const SizedBox(height: 16),
                      _buildLocalModeButton(colorScheme),
                    ],

                    const SizedBox(height: 24),

                    // 底部提示
                    _buildFooter(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== TV 专用布局（宽度 >= 1920）==========

  Widget _buildTvLayout(
    BuildContext context,
    AuthState authState,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Scaffold(
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Form(
            key: _formKey,
            child: Row(
              children: [
                // 左侧：Logo 和品牌区域（40%）
                Expanded(
                  flex: 4,
                  child: Container(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.15),
                    child: Center(child: _buildTvBranding(theme, colorScheme)),
                  ),
                ),

                // 分割线
                Container(
                  width: 1,
                  height: double.infinity,
                  color: colorScheme.outlineVariant,
                ),

                // 右侧：登录表单（60%）
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(TvTheme.contentPadding),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 步骤指示器和标题行
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '登录',
                                      style: theme.textTheme.headlineLarge
                                          ?.copyWith(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(
                                      height: TvTheme.spacingSmall,
                                    ),
                                    Text(
                                      '使用您的账号登录 Songloft',
                                      style: TvTheme.captionStyle(context),
                                    ),
                                  ],
                                ),
                                // 焦点步骤指示器
                                Text(
                                  '$_currentStep / $_totalSteps',
                                  style: TextStyle(
                                    fontSize: TvTheme.fontSizeCaption,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: TvTheme.spacingXLarge),

                            // 用户名
                            _buildTvInputField(
                              context: context,
                              controller: _usernameController,
                              focusNode: _usernameFocusNode,
                              nextFocusNode: _passwordFocusNode,
                              previousFocusNode: null,
                              colorScheme: colorScheme,
                              labelText: '用户名',
                              hintText: '请输入用户名',
                              prefixIcon: Icons.person_outline,
                              autofocus: true,
                              isLastField: false,
                              autofillHints: const [AutofillHints.username],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '请输入用户名';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: TvTheme.spacingLarge),

                            // 密码
                            _buildTvPasswordField(context, colorScheme),
                            const SizedBox(height: TvTheme.spacingLarge),

                            // API 地址 — 嵌入模式下隐藏
                            if (_isApiUrlVisible) ...[
                              _buildTvInputField(
                                context: context,
                                controller: _apiUrlController,
                                focusNode: _apiUrlFocusNode,
                                nextFocusNode: _loginButtonFocusNode,
                                previousFocusNode: _passwordFocusNode,
                                colorScheme: colorScheme,
                                labelText: 'API 地址',
                                hintText: AppConfig.baseUrl,
                                prefixIcon: Icons.cloud_outlined,
                                keyboardType: TextInputType.url,
                                isLastField: true,
                                onSubmit: _handleLogin,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (!value.startsWith('http://') &&
                                        !value.startsWith('https://')) {
                                      return '请输入有效的 URL（以 http:// 或 https:// 开头）';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: TvTheme.spacingLarge),
                            ],

                            // 登录按钮
                            _buildTvLoginButton(
                              context,
                              authState,
                              colorScheme,
                            ),

                            if (_showLocalMode) ...[
                              const SizedBox(height: TvTheme.spacingLarge),
                              OutlinedButton.icon(
                                onPressed: _isLocalModeBootstrapping
                                    ? null
                                    : _handleLocalMode,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(
                                    TvTheme.minButtonSize,
                                  ),
                                  textStyle: TvTheme.buttonStyle(context),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _isLocalModeBootstrapping
                                    ? SizedBox(
                                        height: 28,
                                        width: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    : const Icon(Icons.phone_android),
                                label: Text(
                                  _isLocalModeBootstrapping
                                      ? _localModeHint
                                      : '使用本地模式',
                                ),
                              ),
                            ],

                            const SizedBox(height: TvTheme.spacingXLarge),

                            // 底部提示
                            Text(
                              '© ${DateTime.now().year} Songloft',
                              textAlign: TextAlign.center,
                              style: TvTheme.captionStyle(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// TV 左侧品牌区域
  Widget _buildTvBranding(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Image.asset('assets/icons/app_icon.png', width: 160, height: 160, semanticLabel: 'Songloft'),
        ),
        const SizedBox(height: 40),
        Text(
          'Songloft',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            fontSize: 52,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '自托管本地音乐服务',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: TvTheme.fontSizeBody,
          ),
        ),
      ],
    );
  }

  /// TV 通用输入框
  Widget _buildTvInputField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required FocusNode nextFocusNode,
    required ColorScheme colorScheme,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    FocusNode? previousFocusNode,
    bool autofocus = false,
    bool isLastField = false,
    List<String>? autofillHints,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onSubmit,
  }) {
    return _TvFocusableTextField(
      controller: controller,
      focusNode: focusNode,
      nextFocusNode: nextFocusNode,
      previousFocusNode: previousFocusNode,
      isLastField: isLastField,
      colorScheme: colorScheme,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      autofocus: autofocus,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textInputAction:
          isLastField ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (isLastField && onSubmit != null) {
          onSubmit();
        } else {
          nextFocusNode.requestFocus();
        }
      },
      validator: validator,
    );
  }

  /// TV 密码输入框（带显示/隐藏切换）
  Widget _buildTvPasswordField(BuildContext context, ColorScheme colorScheme) {
    const bool isLast = AppConfig.isEmbedded;
    return _TvFocusableTextField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      nextFocusNode: isLast ? _loginButtonFocusNode : _apiUrlFocusNode,
      previousFocusNode: _usernameFocusNode,
      isLastField: isLast,
      colorScheme: colorScheme,
      labelText: '密码',
      hintText: '请输入密码',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.password],
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (isLast) {
          _handleLogin();
        } else {
          _apiUrlFocusNode.requestFocus();
        }
      },
      suffixIconBuilder:
          (hasFocus) => IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color:
                  hasFocus ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            iconSize: 28,
            tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入密码';
        }
        return null;
      },
    );
  }

  /// TV 登录按钮
  Widget _buildTvLoginButton(
    BuildContext context,
    AuthState authState,
    ColorScheme colorScheme,
  ) {
    return Focus(
      focusNode: _loginButtonFocusNode,
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedScale(
            scale: hasFocus ? 1.08 : 1.0,
            duration: TvTheme.focusAnimationDuration,
            curve: TvTheme.focusAnimationCurve,
            child: AnimatedContainer(
              duration: TvTheme.focusAnimationDuration,
              curve: TvTheme.focusAnimationCurve,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border:
                    hasFocus
                        ? Border.all(
                          color: colorScheme.primary,
                          width: TvTheme.focusBorderWidth,
                        )
                        : null,
                boxShadow:
                    hasFocus
                        ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(
                              alpha: TvTheme.focusGlowOpacity,
                            ),
                            blurRadius: TvTheme.focusShadowBlurRadius,
                            spreadRadius: TvTheme.focusGlowSpreadRadius,
                          ),
                        ]
                        : null,
              ),
              child: FilledButton(
                focusNode: null,
                onPressed: authState.isLoading ? null : _handleLogin,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(TvTheme.minButtonSize),
                  textStyle: TvTheme.buttonStyle(context).copyWith(
                    fontWeight: hasFocus ? FontWeight.bold : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child:
                    authState.isLoading
                        ? SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: colorScheme.onPrimary,
                          ),
                        )
                        : Text(hasFocus ? '按确认键登录' : '登录'),
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== 共用 Widget 方法（非 TV 端使用）==========

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Logo
        Image.asset('assets/icons/app_icon.png', width: 80, height: 80, semanticLabel: 'Songloft'),
        const SizedBox(height: 24),
        Text(
          'Songloft',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '登录以继续',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _usernameController,
      decoration: const InputDecoration(
        labelText: '用户名',
        hintText: '请输入用户名',
        prefixIcon: Icon(Icons.person_outline),
      ),
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入用户名';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入密码',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) => _handleLogin(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入密码';
        }
        return null;
      },
    );
  }

  Widget _buildApiUrlField(ColorScheme colorScheme) {
    final servers = ref.watch(serversProvider).value ?? const <ServerEntry>[];
    if (servers.length >= 2) {
      final current = ref.watch(baseUrlProvider);
      final selected = servers.any((s) => s.url == current)
          ? current
          : servers.first.url;
      return DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: const InputDecoration(
          labelText: '服务器',
          prefixIcon: Icon(Icons.cloud_outlined),
        ),
        items: servers
            .map(
              (s) => DropdownMenuItem(
                value: s.url,
                child: Text(
                  s.name.isNotEmpty ? '${s.name} (${s.url})' : s.url,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (url) {
          if (url != null) ref.read(baseUrlProvider.notifier).set(url);
        },
      );
    }
    return TextFormField(
      controller: _apiUrlController,
      decoration: InputDecoration(
        labelText: 'API 地址',
        hintText: AppConfig.baseUrl,
        prefixIcon: const Icon(Icons.cloud_outlined),
      ),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入 API 地址';
        }
        if (!value.startsWith('http://') && !value.startsWith('https://')) {
          return '请输入有效的 URL（以 http:// 或 https:// 开头）';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton(AuthState authState, ColorScheme colorScheme) {
    return FilledButton(
      onPressed: authState.isLoading ? null : _handleLogin,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child:
          authState.isLoading
              ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimary,
                ),
              )
              : const Text('登录'),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Text(
      '© ${DateTime.now().year} Songloft',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ========== 本地模式 ==========

  static const bool _showLocalMode = !kIsWeb && AppConfig.hasEmbeddedBackend;

  Future<void> _tryAutoLoginLocal() async {
    final runMode = ref.read(runModeProvider);
    if (runMode != RunMode.local) return;

    setState(() {
      _isLocalModeBootstrapping = true;
      _localModeHint = '正在自动登录…';
    });

    try {
      final running = await EmbeddedBackendService.isRunning();
      if (!running) {
        final musicDir = ref.read(localMusicDirProvider);
        if (musicDir == null || musicDir.isEmpty) return;
        setState(() => _localModeHint = '正在启动本地后端…');
        final dataDir = (await getApplicationSupportDirectory()).path;
        final port = await EmbeddedBackendService.start(
          dataDir: dataDir,
          musicDir: musicDir,
        );
        ref.read(baseUrlProvider.notifier).set('http://127.0.0.1:$port');

        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 2)),
        );
        for (var i = 0; i < 10; i++) {
          try {
            final baseUrl = ref.read(baseUrlProvider);
            final resp = await dio.get('$baseUrl/api/v1/health');
            if (resp.statusCode == 200) break;
          } catch (_) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
        dio.close();
      }

      await ref.read(authStateProvider.notifier).login(
        username: 'admin',
        password: 'admin',
      );
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '自动登录失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocalModeBootstrapping = false);
      }
    }
  }

  Widget _buildLocalModeButton(ColorScheme colorScheme) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _isLocalModeBootstrapping ? null : _handleLocalMode,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: _isLocalModeBootstrapping
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              : const Icon(Icons.phone_android),
          label: Text(
            _isLocalModeBootstrapping ? _localModeHint : '使用本地模式',
          ),
        ),
      ],
    );
  }

  Future<void> _handleLocalMode() async {
    setState(() {
      _isLocalModeBootstrapping = true;
      _localModeHint = '正在准备…';
    });

    try {
      var musicDir = ref.read(localMusicDirProvider);
      if (musicDir == null || musicDir.isEmpty) {
        final result = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '选择音乐文件夹',
        );
        if (result == null) {
          setState(() => _isLocalModeBootstrapping = false);
          return;
        }
        await ref.read(localMusicDirProvider.notifier).set(result);
        musicDir = result;
      }

      await ref.read(runModeProvider.notifier).set(RunMode.local);
      await EmbeddedBackendService.ensureStoragePermission();

      setState(() => _localModeHint = '正在启动本地后端…');
      final dataDir = (await getApplicationSupportDirectory()).path;
      final port = await EmbeddedBackendService.start(
        dataDir: dataDir,
        musicDir: musicDir,
      );

      final baseUrl = 'http://127.0.0.1:$port';
      ref.read(baseUrlProvider.notifier).set(baseUrl);

      setState(() => _localModeHint = '正在连接…');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2)));
      for (var i = 0; i < 10; i++) {
        try {
          final resp = await dio.get('$baseUrl/api/v1/health');
          if (resp.statusCode == 200) break;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      dio.close();

      // 尝试恢复本地 session，有效则跳过登录
      final storage = SecureStorageService();
      final restored = await storage.restoreWallet(SecureStorageService.localWalletKey);
      if (restored && !await storage.isAccessTokenExpired()) {
        ref.read(authStateProvider.notifier).setAuthenticated();
      } else {
        setState(() => _localModeHint = '正在登录…');
        final loginDio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
        ));
        final resp = await loginDio.post(
          '${AppConfig.apiPrefix}/auth/login',
          data: {'username': 'admin', 'password': 'admin'},
        );
        if (resp.statusCode == 200 && resp.data != null) {
          await storage.saveTokens(
            accessToken: resp.data['access_token'] ?? '',
            refreshToken: resp.data['refresh_token'] ?? '',
            expiresIn: resp.data['expires_in'] ?? 3600,
          );
        }
        loginDio.close();
        await ref.read(authStateProvider.notifier).checkAuth();
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '本地模式启动失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocalModeBootstrapping = false);
      }
    }
  }
}

// ========== TV 焦点输入框组件 ==========

/// TV 端带焦点高亮效果的输入框
class _TvFocusableTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final FocusNode? previousFocusNode;
  final bool isLastField;
  final ColorScheme colorScheme;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final bool autofocus;
  final bool obscureText;
  final List<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget Function(bool hasFocus)? suffixIconBuilder;
  final String? Function(String?)? validator;

  const _TvFocusableTextField({
    required this.controller,
    required this.focusNode,
    required this.colorScheme,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.nextFocusNode,
    this.previousFocusNode,
    this.isLastField = false,
    this.autofocus = false,
    this.obscureText = false,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIconBuilder,
    this.validator,
  });

  @override
  State<_TvFocusableTextField> createState() => _TvFocusableTextFieldState();
}

class _TvFocusableTextFieldState extends State<_TvFocusableTextField> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = widget.focusNode.hasFocus;
    });
  }

  /// 处理 D-Pad 按键事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (widget.nextFocusNode != null) {
        widget.nextFocusNode!.requestFocus();
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.previousFocusNode != null) {
        widget.previousFocusNode!.requestFocus();
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      if (!widget.isLastField && widget.nextFocusNode != null) {
        widget.nextFocusNode!.requestFocus();
        return KeyEventResult.handled;
      } else if (widget.isLastField && widget.onFieldSubmitted != null) {
        widget.onFieldSubmitted!(widget.controller.text);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _handleKeyEvent,
      child: AnimatedContainer(
        duration: TvTheme.focusAnimationDuration,
        curve: TvTheme.focusAnimationCurve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border:
              _hasFocus
                  ? Border.all(
                    color: colorScheme.primary,
                    width: TvTheme.focusBorderWidth,
                  )
                  : Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
          boxShadow:
              _hasFocus
                  ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: TextFormField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          obscureText: widget.obscureText,
          autofillHints: widget.autofillHints,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          style: TextStyle(
            fontSize: TvTheme.fontSizeBody,
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            labelStyle: TextStyle(
              fontSize: TvTheme.fontSizeCaption,
              color:
                  _hasFocus
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
            ),
            hintStyle: TextStyle(
              fontSize: TvTheme.fontSizeBody,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(
              widget.prefixIcon,
              size: 28,
              color:
                  _hasFocus
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
            ),
            suffixIcon: widget.suffixIconBuilder?.call(_hasFocus),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
            filled: true,
            fillColor:
                _hasFocus
                    ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: colorScheme.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
