import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'l10n/l10n.dart';
import 'state.dart';
import 'ui.dart' show showToast;

/// Global and in-app shortcuts: one table that keyboard handling, Windows global hotkeys,
/// the macOS menu bar and the settings page reference all come from.
/// macOS uses ⌘ / ⌥ / ⇧ / ⌃; Windows uses Ctrl / Alt / Shift / Win instead.
/// While typing, only [AppShortcut.whileTyping] ones (⌘F, Esc) work.

final bool _mac = Platform.isMacOS;

enum ShortcutGroup { playback, ui }

/// Serializable key combination for customizable in-app and system-wide global shortcuts.
class ShortcutBinding {
  const ShortcutBinding({
    required this.keyId,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  final int keyId;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;

  LogicalKeyboardKey get logicalKey =>
      LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);

  SingleActivator toActivator() => SingleActivator(
    logicalKey,
    control: ctrl,
    alt: alt,
    shift: shift,
    meta: meta,
  );

  static ShortcutBinding fromActivator(SingleActivator a) => ShortcutBinding(
    keyId: a.trigger.keyId,
    ctrl: a.control,
    alt: a.alt,
    shift: a.shift,
    meta: a.meta,
  );

  static final Set<LogicalKeyboardKey> _modifierKeys = {
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.superKey,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.numLock,
    LogicalKeyboardKey.scrollLock,
    LogicalKeyboardKey.fn,
    LogicalKeyboardKey.hyper,
  };

  static bool isModifierOnly(LogicalKeyboardKey key) =>
      _modifierKeys.contains(key);

  /// Captures a key combination from [e] and the current modifier state in [kb].
  /// Returns null when only modifier keys were pressed.
  static ShortcutBinding? fromKeyEvent(KeyEvent e, HardwareKeyboard kb) {
    final k = e.logicalKey;
    if (isModifierOnly(k)) return null;
    return ShortcutBinding(
      keyId: k.keyId,
      ctrl: kb.isControlPressed,
      alt: kb.isAltPressed,
      shift: kb.isShiftPressed,
      meta: kb.isMetaPressed,
    );
  }

  /// Whether this binding is safe and supported as a Windows system-wide hotkey:
  /// requires a supported virtual key plus at least one modifier or a function/media key.
  bool get isValidGlobal {
    if (toWin32VirtualKey() == null) return false;
    if (ctrl || alt || shift || meta) return true;
    return _isFunctionOrMediaKey(logicalKey);
  }

  static bool _isFunctionOrMediaKey(LogicalKeyboardKey k) {
    final id = k.keyId;
    // F1..F12
    if (id >= LogicalKeyboardKey.f1.keyId &&
        id <= LogicalKeyboardKey.f12.keyId) {
      return true;
    }
    return k == LogicalKeyboardKey.mediaPlayPause ||
        k == LogicalKeyboardKey.mediaStop ||
        k == LogicalKeyboardKey.mediaTrackNext ||
        k == LogicalKeyboardKey.mediaTrackPrevious ||
        k == LogicalKeyboardKey.audioVolumeUp ||
        k == LogicalKeyboardKey.audioVolumeDown ||
        k == LogicalKeyboardKey.audioVolumeMute;
  }

  /// Win32 RegisterHotKey modifier bitmask (MOD_ALT=1, MOD_CONTROL=2, MOD_SHIFT=4, MOD_WIN=8).
  int get win32Modifiers =>
      (alt ? 0x0001 : 0) |
      (ctrl ? 0x0002 : 0) |
      (shift ? 0x0004 : 0) |
      (meta ? 0x0008 : 0);

  /// Maps this logical key to a Win32 virtual-key code (VK_*), or null if unsupported.
  int? toWin32VirtualKey() {
    final k = logicalKey;
    final id = k.keyId;
    // A..Z
    if (id >= LogicalKeyboardKey.keyA.keyId &&
        id <= LogicalKeyboardKey.keyZ.keyId) {
      return 0x41 + (id - LogicalKeyboardKey.keyA.keyId);
    }
    // 0..9
    if (id >= LogicalKeyboardKey.digit0.keyId &&
        id <= LogicalKeyboardKey.digit9.keyId) {
      return 0x30 + (id - LogicalKeyboardKey.digit0.keyId);
    }
    // Numpad 0..9
    if (id >= LogicalKeyboardKey.numpad0.keyId &&
        id <= LogicalKeyboardKey.numpad9.keyId) {
      return 0x60 + (id - LogicalKeyboardKey.numpad0.keyId);
    }
    // F1..F12
    if (id >= LogicalKeyboardKey.f1.keyId &&
        id <= LogicalKeyboardKey.f12.keyId) {
      return 0x70 + (id - LogicalKeyboardKey.f1.keyId);
    }
    if (k == LogicalKeyboardKey.space) return 0x20;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      return 0x0D;
    }
    if (k == LogicalKeyboardKey.escape) return 0x1B;
    if (k == LogicalKeyboardKey.tab) return 0x09;
    if (k == LogicalKeyboardKey.backspace) return 0x08;
    if (k == LogicalKeyboardKey.delete) return 0x2E;
    if (k == LogicalKeyboardKey.insert) return 0x2D;
    if (k == LogicalKeyboardKey.home) return 0x24;
    if (k == LogicalKeyboardKey.end) return 0x23;
    if (k == LogicalKeyboardKey.pageUp) return 0x21;
    if (k == LogicalKeyboardKey.pageDown) return 0x22;
    if (k == LogicalKeyboardKey.arrowLeft) return 0x25;
    if (k == LogicalKeyboardKey.arrowUp) return 0x26;
    if (k == LogicalKeyboardKey.arrowRight) return 0x27;
    if (k == LogicalKeyboardKey.arrowDown) return 0x28;
    if (k == LogicalKeyboardKey.comma) return 0xBC;
    if (k == LogicalKeyboardKey.period) return 0xBE;
    if (k == LogicalKeyboardKey.slash) return 0xBF;
    if (k == LogicalKeyboardKey.semicolon) return 0xBA;
    if (k == LogicalKeyboardKey.quoteSingle) return 0xDE;
    if (k == LogicalKeyboardKey.bracketLeft) return 0xDB;
    if (k == LogicalKeyboardKey.bracketRight) return 0xDD;
    if (k == LogicalKeyboardKey.backslash) return 0xDC;
    if (k == LogicalKeyboardKey.minus) return 0xBD;
    if (k == LogicalKeyboardKey.equal) return 0xBB;
    if (k == LogicalKeyboardKey.backquote) return 0xC0;
    if (k == LogicalKeyboardKey.numpadAdd) return 0x6B;
    if (k == LogicalKeyboardKey.numpadSubtract) return 0x6D;
    if (k == LogicalKeyboardKey.numpadMultiply) return 0x6A;
    if (k == LogicalKeyboardKey.numpadDivide) return 0x6F;
    if (k == LogicalKeyboardKey.numpadDecimal) return 0x6E;
    if (k == LogicalKeyboardKey.mediaPlayPause) return 0xB3;
    if (k == LogicalKeyboardKey.mediaStop) return 0xB2;
    if (k == LogicalKeyboardKey.mediaTrackNext) return 0xB0;
    if (k == LogicalKeyboardKey.mediaTrackPrevious) return 0xB1;
    if (k == LogicalKeyboardKey.audioVolumeMute) return 0xAD;
    if (k == LogicalKeyboardKey.audioVolumeDown) return 0xAE;
    if (k == LogicalKeyboardKey.audioVolumeUp) return 0xAF;
    return null;
  }

  /// Keycaps for display in Settings (macOS symbols or Windows/Linux text).
  List<String> keyLabels(AppLocalizations l) => [
    if (_mac) ...[
      if (ctrl) '⌃',
      if (alt) '⌥',
      if (shift) '⇧',
      if (meta) '⌘',
    ] else ...[
      if (ctrl) 'Ctrl',
      if (alt) 'Alt',
      if (shift) 'Shift',
      if (meta) 'Win',
    ],
    _keyCapName(logicalKey, l),
  ];

  String formatLabel(AppLocalizations l) => keyLabels(l).join(_mac ? '' : '+');

  Map<String, Object?> toJson() => {
    'keyId': keyId,
    if (ctrl) 'ctrl': true,
    if (alt) 'alt': true,
    if (shift) 'shift': true,
    if (meta) 'meta': true,
  };

  static ShortcutBinding? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final keyId = raw['keyId'];
    if (keyId is! int) return null;
    return ShortcutBinding(
      keyId: keyId,
      ctrl: raw['ctrl'] == true,
      alt: raw['alt'] == true,
      shift: raw['shift'] == true,
      meta: raw['meta'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShortcutBinding &&
      other.keyId == keyId &&
      other.ctrl == ctrl &&
      other.alt == alt &&
      other.shift == shift &&
      other.meta == meta;

  @override
  int get hashCode => Object.hash(keyId, ctrl, alt, shift, meta);
}

String _keyCapName(LogicalKeyboardKey k, AppLocalizations l) {
  if (k == LogicalKeyboardKey.space) return l.shortcutSpaceKey;
  if (k == LogicalKeyboardKey.escape) return 'Esc';
  if (k == LogicalKeyboardKey.arrowUp) return '↑';
  if (k == LogicalKeyboardKey.arrowDown) return '↓';
  if (k == LogicalKeyboardKey.arrowLeft) return '←';
  if (k == LogicalKeyboardKey.arrowRight) return '→';
  if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
    return 'Enter';
  }
  if (k == LogicalKeyboardKey.backspace) return 'Backspace';
  if (k == LogicalKeyboardKey.delete) return 'Del';
  if (k == LogicalKeyboardKey.tab) return 'Tab';
  if (k == LogicalKeyboardKey.comma) return ',';
  if (k == LogicalKeyboardKey.period) return '.';
  if (k == LogicalKeyboardKey.slash) return '/';
  if (k == LogicalKeyboardKey.semicolon) return ';';
  if (k == LogicalKeyboardKey.quoteSingle) return "'";
  if (k == LogicalKeyboardKey.bracketLeft) return '[';
  if (k == LogicalKeyboardKey.bracketRight) return ']';
  if (k == LogicalKeyboardKey.backslash) return '\\';
  if (k == LogicalKeyboardKey.minus) return '-';
  if (k == LogicalKeyboardKey.equal) return '=';
  if (k == LogicalKeyboardKey.backquote) return '`';
  if (k == LogicalKeyboardKey.mediaPlayPause) return 'Play/Pause';
  if (k == LogicalKeyboardKey.mediaTrackNext) return 'Next';
  if (k == LogicalKeyboardKey.mediaTrackPrevious) return 'Prev';
  if (k == LogicalKeyboardKey.mediaStop) return 'Stop';
  final label = k.keyLabel.trim();
  if (label.isNotEmpty) {
    return label.length == 1 ? label.toUpperCase() : label;
  }
  return k.debugName ?? 'Key';
}

class AppShortcut {
  const AppShortcut({
    required this.id,
    required this.group,
    required this.label,
    required this.keys,
    required this.activators,
    required this.run,
    this.whileTyping = false,
    this.inMenu = true,
    this.repeatable = false,
    this.customizable = true,
    this.globalSupported = false,
  });

  final String id;

  /// Groups on the settings page: playback, interface.
  final ShortcutGroup group;
  final String Function(AppLocalizations l) label;

  /// Keycaps shown on the settings page (mac notation; [keysFor] converts to text on Windows);
  /// `null` is the "to" between keycaps, and `'SPACE'` becomes the localised space name via [keysFor].
  final List<String?> keys;
  final List<SingleActivator> activators;

  /// Returning false means it wasn't handled this time (e.g. Esc with Now Playing closed), so the key keeps propagating.
  final bool Function(AppState app) run;
  final bool whileTyping;

  /// Shown with its shortcut in the macOS menu bar. Arrow keys and space are left out: the system menu may get keys before text fields,
  /// stealing cursor movement and space input from them.
  final bool inMenu;

  /// Whether holding the key repeats (volume and seeking).
  final bool repeatable;

  /// Whether the user can rebind this shortcut in Settings.
  final bool customizable;

  /// Whether this action can also be assigned a system-wide global hotkey on Windows.
  final bool globalSupported;

  ShortcutBinding? get defaultBinding =>
      activators.isEmpty ? null : ShortcutBinding.fromActivator(activators.first);
}

/// Primary modifier: ⌘ on mac, Ctrl on Windows.
SingleActivator _cmd(LogicalKeyboardKey k, {bool alt = false}) =>
    SingleActivator(k, meta: _mac, control: !_mac, alt: alt);

bool _do(void Function() f) {
  f();
  return true;
}

final List<AppShortcut> appShortcuts = [
  // ───── Playback ─────
  AppShortcut(
    id: 'playPause',
    group: ShortcutGroup.playback,
    label: (l) => l.shortcutPlayPause,
    keys: const ['SPACE'],
    activators: const [SingleActivator(LogicalKeyboardKey.space)],
    run: (a) => _do(a.togglePlay),
    inMenu: false,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'next',
    group: ShortcutGroup.playback,
    label: (l) => l.actionNext,
    keys: const ['⌘', '→'],
    activators: [_cmd(LogicalKeyboardKey.arrowRight)],
    run: (a) => _do(a.next),
    inMenu: false,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'prev',
    group: ShortcutGroup.playback,
    label: (l) => l.actionPrev,
    keys: const ['⌘', '←'],
    activators: [_cmd(LogicalKeyboardKey.arrowLeft)],
    run: (a) => _do(a.prev),
    inMenu: false,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'seekForward',
    group: ShortcutGroup.playback,
    label: (l) => l.shortcutSeekForward,
    keys: const ['⇧', '→'],
    activators: const [
      SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
    ],
    run: (a) => _do(() => a.seekBy(5)),
    inMenu: false,
    repeatable: true,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'seekBackward',
    group: ShortcutGroup.playback,
    label: (l) => l.shortcutSeekBackward,
    keys: const ['⇧', '←'],
    activators: const [
      SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
    ],
    run: (a) => _do(() => a.seekBy(-5)),
    inMenu: false,
    repeatable: true,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'volumeUp',
    group: ShortcutGroup.playback,
    label: (l) => l.shortcutVolumeUp,
    keys: const ['⌘', '↑'],
    activators: [_cmd(LogicalKeyboardKey.arrowUp)],
    run: (a) => _do(() => a.volumeBy(0.1)),
    inMenu: false,
    repeatable: true,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'volumeDown',
    group: ShortcutGroup.playback,
    label: (l) => l.shortcutVolumeDown,
    keys: const ['⌘', '↓'],
    activators: [_cmd(LogicalKeyboardKey.arrowDown)],
    run: (a) => _do(() => a.volumeBy(-0.1)),
    inMenu: false,
    repeatable: true,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'mute',
    group: ShortcutGroup.playback,
    label: (l) => l.shortcutMute,
    keys: const ['⌥', '⌘', '↓'],
    activators: [_cmd(LogicalKeyboardKey.arrowDown, alt: true)],
    run: (a) => _do(a.toggleMute),
    inMenu: false,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'shuffle',
    group: ShortcutGroup.playback,
    label: (l) => l.actionShuffle,
    keys: const ['⌘', 'S'],
    activators: [_cmd(LogicalKeyboardKey.keyS)],
    run: (a) => _do(a.toggleShuffle),
    globalSupported: true,
  ),
  AppShortcut(
    id: 'repeat',
    group: ShortcutGroup.playback,
    label: (l) => l.shortcutRepeat,
    keys: const ['⌘', 'R'],
    activators: [_cmd(LogicalKeyboardKey.keyR)],
    run: (a) => _do(a.toggleRepeat),
    globalSupported: true,
  ),
  AppShortcut(
    id: 'likeCurrent',
    group: ShortcutGroup.playback,
    label: (l) => l.shortcutLikeCurrent,
    keys: const ['⌘', 'L'],
    activators: [_cmd(LogicalKeyboardKey.keyL)],
    run: (a) => _do(a.toggleLike),
    globalSupported: true,
  ),
  // ───── Interface ─────
  AppShortcut(
    id: 'toggleWindow',
    group: ShortcutGroup.ui,
    label: (l) => l.shortcutToggleWindow,
    keys: const [],
    activators: const [],
    run: (a) => _do(a.toggleWindowVisible),
    inMenu: false,
    globalSupported: true,
  ),
  AppShortcut(
    id: 'nowPlaying',
    group: ShortcutGroup.ui,
    label: (l) => l.miniOpenNowPlaying,
    keys: const ['⌘', 'P'],
    activators: [_cmd(LogicalKeyboardKey.keyP)],
    run: (a) => _do(() => a.npOpen ? a.closeNowPlaying() : a.openNowPlaying()),
    globalSupported: true,
  ),
  AppShortcut(
    id: 'dismiss',
    group: ShortcutGroup.ui,
    label: (l) => l.shortcutDismissOverlay,
    keys: const ['Esc'],
    activators: const [SingleActivator(LogicalKeyboardKey.escape)],
    // Only handles Now Playing; dialogs take Esc themselves (passed on to them when unhandled)
    run: (a) {
      if (!a.npOpen) return false;
      a.closeNowPlaying();
      return true;
    },
    whileTyping: true,
    inMenu: false,
  ),
  AppShortcut(
    id: 'search',
    group: ShortcutGroup.ui,
    label: (l) => l.navSearch,
    keys: const ['⌘', 'F'],
    activators: [_cmd(LogicalKeyboardKey.keyF)],
    run: (a) => _do(() {
      a.closeNowPlaying();
      a.focusSearch();
    }),
    whileTyping: true,
  ),
  AppShortcut(
    id: 'back',
    group: ShortcutGroup.ui,
    label: (l) => l.shortcutBack,
    keys: const ['⌘', '['],
    activators: [_cmd(LogicalKeyboardKey.bracketLeft)],
    run: (a) => _do(a.back),
  ),
  AppShortcut(
    id: 'forward',
    group: ShortcutGroup.ui,
    label: (l) => l.shortcutForward,
    keys: const ['⌘', ']'],
    activators: [_cmd(LogicalKeyboardKey.bracketRight)],
    run: (a) => _do(a.forward),
  ),
  AppShortcut(
    id: 'settings',
    group: ShortcutGroup.ui,
    label: (l) => l.navSettings,
    keys: const ['⌘', ','],
    activators: [_cmd(LogicalKeyboardKey.comma)],
    run: (a) => _do(() {
      a.closeNowPlaying();
      a.go('/settings');
    }),
  ),
  AppShortcut(
    id: 'switchTab',
    group: ShortcutGroup.ui,
    label: (l) => l.shortcutSwitchTab,
    keys: const ['⌘', '1', null, '4'],
    activators: [
      _cmd(LogicalKeyboardKey.digit1),
      _cmd(LogicalKeyboardKey.digit2),
      _cmd(LogicalKeyboardKey.digit3),
      _cmd(LogicalKeyboardKey.digit4),
    ],
    // Which page to go to is computed from the key in [_onKey]
    run: (_) => true,
    inMenu: false,
    customizable: false,
  ),
];

const _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];

/// Keycap text for the settings page: Windows replaces the symbols with Ctrl / Alt / Shift.
List<String?> keysFor(
  AppShortcut s,
  AppLocalizations l, [
  ShortcutBinding? binding,
]) {
  if (!s.customizable) {
    return [
      for (final k in s.keys)
        k == 'SPACE'
            ? l.shortcutSpaceKey
            : (_mac
                  ? k
                  : switch (k) {
                      '⌘' => 'Ctrl',
                      '⌥' => 'Alt',
                      '⇧' => 'Shift',
                      _ => k,
                    }),
    ];
  }
  if (binding == null) return const [];
  return binding.keyLabels(l);
}

/// Focus is in a text field (the user is typing).
bool get _typing {
  final c = FocusManager.instance.primaryFocus?.context;
  if (c == null) return false;
  return c.widget is EditableText ||
      c.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Installs a global handler on [HardwareKeyboard]: it gets keys before focus handling in pages,
/// so space in the shelf or Coverflow isn't handled twice.
class ShortcutHandler {
  ShortcutHandler(this.app);
  final AppState app;

  void attach() => HardwareKeyboard.instance.addHandler(_onKey);
  void detach() => HardwareKeyboard.instance.removeHandler(_onKey);

  bool _onKey(KeyEvent e) {
    if (e is KeyUpEvent || app.recordingShortcut) return false;
    final typing = _typing;
    for (final s in appShortcuts) {
      if (typing && !s.whileTyping) continue;
      if (!s.customizable) {
        for (final a in s.activators) {
          if (!a.accepts(e, HardwareKeyboard.instance)) continue;
          if (e is KeyRepeatEvent && !s.repeatable) return true;
          if (_digits.contains(a.trigger)) {
            final tabs = app.visibleTabs;
            final i = _digits.indexOf(a.trigger);
            if (i < tabs.length) {
              app.closeNowPlaying();
              app.goTab(tabs[i]);
            }
            return true;
          }
          return s.run(app);
        }
        continue;
      }
      final binding = app.inAppShortcutOf(s.id);
      if (binding == null) continue;
      if (!binding.toActivator().accepts(e, HardwareKeyboard.instance)) continue;
      // Key repeat only for volume and seeking
      if (e is KeyRepeatEvent && !s.repeatable) {
        return true;
      }
      return s.run(app);
    }
    return false;
  }
}

/// Registers system-wide global hotkeys and media keys on Windows via `yesplaymusic/hotkeys`.
class GlobalHotkeys {
  GlobalHotkeys(this.app);
  final AppState app;

  static bool get isSupported => Platform.isWindows;
  static const _channel = MethodChannel('yesplaymusic/hotkeys');

  bool _suspended = false;

  void attach() {
    if (!isSupported) return;
    _channel.setMethodCallHandler(_onMethodCall);
    app.onShortcutsChanged = () => sync();
    sync();
  }

  void detach() {
    if (!isSupported) return;
    app.onShortcutsChanged = null;
    _channel.setMethodCallHandler(null);
    _channel.invokeMethod('suspend').catchError((_) => null);
  }

  Future<void> suspend() async {
    if (!isSupported) return;
    _suspended = true;
    await _channel.invokeMethod('suspend').catchError((_) => null);
  }

  Future<void> resume() async {
    if (!isSupported) return;
    _suspended = false;
    await sync(showConflictToast: true);
  }

  Future<void> sync({bool showConflictToast = false}) async {
    if (!isSupported || _suspended) return;
    final bindings = <Map<String, Object?>>[];
    for (final s in appShortcuts) {
      if (!s.globalSupported) continue;
      final b = app.globalShortcutOf(s.id);
      if (b == null) continue;
      final vk = b.toWin32VirtualKey();
      if (vk == null || !b.isValidGlobal) continue;
      bindings.add({
        'id': s.id,
        'vk': vk,
        'mods': b.win32Modifiers,
      });
    }
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('sync', {
        'enabled': app.globalShortcutsEnabled,
        'mediaKeys': app.mediaKeysEnabled,
        'bindings': bindings,
      });
      final failed = <String>[
        for (final x in raw ?? const [])
          if (x is String) x,
      ];
      app.setGlobalShortcutConflicts(failed);
      if (showConflictToast && failed.isNotEmpty) {
        final firstId = failed.first;
        final b = app.globalShortcutOf(firstId);
        if (b != null) {
          showToast(L.shortcutConflict(b.formatLabel(L)));
        }
      }
    } catch (_) {
      // Ignored in tests or platforms without native registration.
    }
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'triggered') return;
    final id = call.arguments;
    if (id is! String) return;
    switch (id) {
      case 'mediaPlayPause':
        app.togglePlay();
      case 'mediaNext':
        app.next();
      case 'mediaPrev':
        app.prev();
      case 'mediaStop':
        if (app.playing) app.togglePlay();
      default:
        for (final s in appShortcuts) {
          if (s.id == id) {
            s.run(app);
            break;
          }
        }
    }
  }
}

/// macOS menu bar: app, playback, view, window. Items with shortcuts fire only once when pressed —
/// if keyboard handling gets the key first the menu doesn't run; menu items also don't run while typing (except ⌘F).
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({super.key, required this.app, required this.child});
  final AppState app;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!_mac) return child;
    final l = context.l10n;
    AppShortcut by(String id) => appShortcuts.firstWhere((s) => s.id == id);
    PlatformMenuItem item(String id, {String? title}) {
      final s = by(id);
      final custom = s.customizable ? app.inAppShortcutOf(id)?.toActivator() : null;
      return PlatformMenuItem(
        label: title ?? s.label(l),
        shortcut: s.inMenu ? (custom ?? s.activators.firstOrNull) : null,
        onSelected: () {
          if (_typing && !s.whileTyping) return;
          s.run(app);
        },
      );
    }

    PlatformMenuItem tab(int i, String label) => PlatformMenuItem(
      label: label,
      onSelected: () {
        if (_typing) return;
        app.closeNowPlaying();
        app.goTab(i);
      },
    );

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'YesPlayMusic',
          menus: [
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.about,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [item('settings', title: l.menuBarSettings)],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l.shortcutGroupPlayback,
          menus: [
            PlatformMenuItemGroup(
              members: [item('playPause'), item('next'), item('prev')],
            ),
            PlatformMenuItemGroup(
              members: [item('seekForward'), item('seekBackward')],
            ),
            PlatformMenuItemGroup(
              members: [item('volumeUp'), item('volumeDown'), item('mute')],
            ),
            PlatformMenuItemGroup(
              members: [item('shuffle'), item('repeat'), item('likeCurrent')],
            ),
          ],
        ),
        PlatformMenu(
          label: l.menuBarView,
          menus: [
            PlatformMenuItemGroup(
              members: [
                item('nowPlaying', title: l.npTitle),
                item('search'),
              ],
            ),
            PlatformMenuItemGroup(members: [item('back'), item('forward')]),
            PlatformMenuItemGroup(
              members: [
                if (app.hasHome) tab(0, l.navHome),
                if (app.hasDiscover) tab(1, l.navDiscover),
                tab(2, l.navLibrary),
                tab(3, l.navSearchPage),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l.menuBarWindow,
          menus: const [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
