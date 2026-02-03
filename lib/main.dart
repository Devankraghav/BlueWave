import 'package:flutter/material.dart';
import 'SplashScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'poppins',
      ),
      debugShowCheckedModeBanner: false,
      title: 'BlueWave',
      home: SplashScreen(),
      // Start with splash
    );
  }
}