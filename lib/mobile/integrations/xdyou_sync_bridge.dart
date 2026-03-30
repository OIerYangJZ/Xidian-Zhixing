/// 树洞主 App → XDYou 子 App 状态同步的函数桥接层。
/// 避免 xdyou_bootstrap.dart 与 app_settings_store.dart 之间的循环 import。
///
/// 使用方式：
/// - xdyou_bootstrap.dart: 调用 `registerXdyouSyncFunctions(...)` 注册同步函数
/// - app_settings_store.dart: 调用 `_syncThemeToXdyou?.call()` 执行同步

typedef _SyncThemeFn = Future<void> Function();
typedef _SyncLocaleFn = Future<void> Function();

_SyncThemeFn? _syncThemeToXdyou;
_SyncLocaleFn? _syncLocaleToXdyou;

/// 注册同步函数（由 xdyou_bootstrap.dart 在 `ensureXdyouEmbedInitialized` 时调用）。
void registerXdyouSyncFunctions({
  required _SyncThemeFn syncTheme,
  required _SyncLocaleFn syncLocale,
}) {
  _syncThemeToXdyou = syncTheme;
  _syncLocaleToXdyou = syncLocale;
}

/// 执行主题同步到 XDYou（如尚未注册则静默跳过）。
Future<void> callSyncThemeToXdyou() async {
  try {
    await _syncThemeToXdyou?.call();
  } catch (_) {}
}

/// 执行语言同步到 XDYou（如尚未注册则静默跳过）。
Future<void> callSyncLocaleToXdyou() async {
  try {
    await _syncLocaleToXdyou?.call();
  } catch (_) {}
}
