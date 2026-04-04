import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 80,
              color: Color(0xFF35CA67),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(
              color: Color(0xFF35CA67),
            ),
          ],
        ),
      ),
    );
  }
}
