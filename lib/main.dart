import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_pulse/core/database/database_helper.dart';
import 'package:wallet_pulse/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper.instance.database;

  runApp(const ProviderScope(child: FoliaApp()));
}

class FoliaApp extends StatelessWidget {
  const FoliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FOLIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      home: const SplashScreen(),
    );
  }
}
