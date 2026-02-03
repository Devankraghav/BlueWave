import 'package:flutter/material.dart';
import 'dart:async';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';
import 'AuthPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'HomePage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _iconController;
  late Animation<double> _iconX;
  late Timer _navigationTimer;
  bool _animationReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Wait for layout before accessing screen width
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimationAndTimer();
    });
  }

  void _startAnimationAndTimer() {
    final screenWidth = MediaQuery.of(context).size.width;

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _iconX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: screenWidth + 50,
          end: screenWidth * 0.7,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(screenWidth * 0.7),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: screenWidth * 0.7,
          end: -50,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_iconController);

    setState(() {
      _animationReady = true;
    });

    _iconController.forward();

    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Already logged in ✅
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        } else {
          // Not logged in ❌
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AuthPage()),
          );
        }
      }
    });

  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _iconController.dispose();
      _navigationTimer.cancel();
      _startAnimationAndTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _iconController.dispose();
    _navigationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 🌊 Wave background
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 300,
              child: WaveWidget(
                config: CustomConfig(
                  gradients: [
                    [Colors.blue.shade900, Colors.blue.shade400],
                    [Colors.blue.shade300, Colors.lightBlueAccent.shade100],
                  ],
                  durations: [5000, 7000],
                  heightPercentages: [0.35, 0.40],
                  blur: const MaskFilter.blur(BlurStyle.solid, 3),
                  gradientBegin: Alignment.bottomLeft,
                  gradientEnd: Alignment.topRight,
                ),
                waveAmplitude: 35,
                size: const Size(double.infinity, double.infinity),
                backgroundColor: Colors.white,
              ),
            ),
          ),

          // 🔵 Logo + Name
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  width:240,
                ),
              ],
            ),
          ),

          // 💬 Moving and fading message icon
          if (_animationReady)
            AnimatedBuilder(
              animation: _iconController,
              builder: (context, child) {
                double currentX = _iconX.value;
                double opacity = 1.0;

                // Fade out when reaching the left third
                if (currentX < screenWidth * 0.3) {
                  opacity = (currentX + 50) / (screenWidth * 0.3);
                  opacity = opacity.clamp(0.0, 1.0);
                }

                return Positioned(
                  bottom: 140,
                  left: currentX,
                  child: Opacity(
                    opacity: opacity,
                    child: child!,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.message, color: Colors.white, size: 28),
              ),
            ),
        ],
      ),
    );
  }
}