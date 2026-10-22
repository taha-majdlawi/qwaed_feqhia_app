import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'services/download_service.dart';
import 'services/player_controller.dart';
import 'services/storage_service.dart';
import 'state/library_state.dart';
import 'state/settings_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initAudioBackend();
  await StorageService.init();
  await PlayerController.instance.initAudioSession();

  runApp(const QawaidApp());
}

/// تهيئة طبقة الصوت حسب المنصّة.
Future<void> _initAudioBackend() async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
    return;
  }
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.qawaid.fiqhiyya.audio',
        androidNotificationChannelName: 'تشغيل الحلقات',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      );
    } catch (e) {
      debugPrint('تعذّرت تهيئة التشغيل في الخلفية: $e');
    }
  }
}

class QawaidApp extends StatelessWidget {
  const QawaidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsState()),
        ChangeNotifierProvider(create: (_) => LibraryState()..load()),
        ChangeNotifierProvider.value(value: PlayerController.instance),
        ChangeNotifierProvider.value(value: DownloadService.instance),
      ],
      child: Consumer<SettingsState>(
        builder: (context, settings, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
