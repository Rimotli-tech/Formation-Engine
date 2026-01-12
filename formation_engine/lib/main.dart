import 'package:flutter/material.dart';
import 'football_field_view.dart';
import 'package:rive/rive.dart' as rive;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await rive.RiveNative.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App!!',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const FootballFieldView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

