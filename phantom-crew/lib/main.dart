import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game/screens/main_menu.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();
  runApp(PhantomCrewApp(prefs: prefs));
}

class PhantomCrewApp extends StatelessWidget {
  final SharedPreferences prefs;
  const PhantomCrewApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phantom Crew',
      debugShowCheckedModeBanner: false,
      theme: PhantomTheme.dark,
      home: MainMenuScreen(prefs: prefs),
    );
  }
}
