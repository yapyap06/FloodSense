import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/locale_provider.dart';
import 'features/auth/welcome_screen.dart';
import 'features/volunteer/active_mission_provider.dart';

class FloodSenseApp extends StatelessWidget {
  const FloodSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        StreamProvider<User?>(
          create: (_) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
        ChangeNotifierProxyProvider<User?, ActiveMissionProvider>(
          create: (_) => ActiveMissionProvider(''),
          update: (_, user, prev) {
            final uid = user?.uid ?? '';
            if (prev != null && prev.uid == uid) return prev;
            return ActiveMissionProvider(uid);
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final localeProvider = context.watch<LocaleProvider>();
          return MaterialApp(
            title: 'FloodSense Malaysia',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                // Allows normal finger touch
                // Allows mouse scroll/drag in emulators/web
                ...const MaterialScrollBehavior().dragDevices,
                PointerDeviceKind.mouse, 
              },
            ),
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('ms'),
              Locale('zh'),
            ],
            home: const WelcomeScreen(),
          );
        },
      ),
    );
  }
}
