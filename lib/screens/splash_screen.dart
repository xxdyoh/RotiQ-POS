import 'package:flutter/material.dart';
import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../services/session_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await SessionManager.loadSession();
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextScreen = _isLoggedIn ? const HomeScreen() : const LoginScreen();

    return FlutterSplashScreen.fadeIn(
      backgroundColor: Colors.white,
      onInit: () {
        debugPrint("ROTIQ POS Splash Screen - Init");
      },
      onEnd: () {
        debugPrint("ROTIQ POS Splash Screen - End");
      },
      onAnimationEnd: () => debugPrint("ROTIQ POS Splash Screen - Fade In Complete"),
      childWidget: SizedBox(
        height: 200,
        width: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/logo.png",
              height: 120,
              width: 120,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 20),
            Text(
              'Cake & Bakery',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF6A918),
              ),
            ),
          ],
        ),
      ),
      nextScreen: nextScreen,
    );
  }
}