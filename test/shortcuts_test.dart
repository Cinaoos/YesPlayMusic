import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yesplaymusic/l10n/l10n.dart';
import 'package:yesplaymusic/pages/settings.dart';
import 'package:yesplaymusic/shortcuts.dart';
import 'package:yesplaymusic/state.dart';
import 'package:yesplaymusic/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ShortcutBinding round-trips JSON and maps Win32 virtual keys', () {
    final binding = ShortcutBinding(
      keyId: LogicalKeyboardKey.keyP.keyId,
      ctrl: true,
      alt: true,
    );
    final decoded = ShortcutBinding.fromJson(binding.toJson());
    expect(decoded, binding);
    expect(decoded!.toWin32VirtualKey(), 0x50);
    expect(decoded.win32Modifiers, 0x0002 | 0x0001);
    expect(decoded.isValidGlobal, isTrue);

    final bareLetter = ShortcutBinding(keyId: LogicalKeyboardKey.keyA.keyId);
    expect(bareLetter.isValidGlobal, isFalse);

    final f8 = ShortcutBinding(keyId: LogicalKeyboardKey.f8.keyId);
    expect(f8.toWin32VirtualKey(), 0x77);
    expect(f8.isValidGlobal, isTrue);

    final media = ShortcutBinding(keyId: LogicalKeyboardKey.mediaPlayPause.keyId);
    expect(media.toWin32VirtualKey(), 0xB3);
    expect(media.isValidGlobal, isTrue);
  });

  test('AppState defaults keepRunning on Windows and manages custom shortcuts', () {
    final app = AppState();
    addTearDown(app.dispose);

    if (Platform.isWindows) {
      expect(app.keepRunning, isTrue);
    }

    final custom = ShortcutBinding(
      keyId: LogicalKeyboardKey.keyK.keyId,
      ctrl: true,
      shift: true,
    );
    app.setInAppShortcut('playPause', custom);
    expect(app.inAppShortcutOf('playPause'), custom);

    app.setGlobalShortcut('next', custom);
    expect(app.globalShortcutOf('next'), custom);

    app.resetShortcuts();
    expect(
      app.inAppShortcutOf('playPause'),
      ShortcutBinding(keyId: LogicalKeyboardKey.space.keyId),
    );
    expect(app.globalShortcutOf('next'), isNull);
  });

  testWidgets('SettingsPage renders global shortcuts UI and opens recorder dialog', (
    t,
  ) async {
    final app = AppState();
    addTearDown(app.dispose);
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF0B0B0D),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, _) {
          syncGlobalL10n(context);
          return ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              app.applyTheme();
              return AppScope(
                state: app,
                child: DefaultTextStyle(
                  style: ts(14),
                  child: Overlay(
                    initialEntries: [
                      OverlayEntry(
                        builder: (_) => const SettingsPage.withMediaKeysSupport(
                          supported: false,
                          globalHotkeysSupported: true,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
    await t.pump(const Duration(milliseconds: 200));

    await t.tap(find.text('快捷键'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('全局快捷键'), findsOneWidget);
    expect(find.text('启用全局快捷键'), findsOneWidget);
    expect(find.text('系统媒体键'), findsOneWidget);
    expect(find.text('显示 / 隐藏窗口'), findsWidgets);
    expect(find.text('恢复默认快捷键'), findsOneWidget);

    await t.tap(find.text('空格').first);
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('请按下组合键…'), findsOneWidget);
    expect(app.recordingShortcut, isTrue);

    await t.tap(find.text('取消'));
    await t.pump(const Duration(milliseconds: 100));
    expect(app.recordingShortcut, isFalse);
  });
}
