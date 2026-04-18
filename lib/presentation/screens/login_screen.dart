import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import 'package:namma_turfy/presentation/providers/auth_providers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.sports_soccer,
                size: 80,
                color: Color(0xFF35CA67),
              ),
              const SizedBox(height: 16),
              Text(
                'Namma Turfy',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF35CA67),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Book your favorite sports arena in seconds',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              if (authState.isLoading)
                const CircularProgressIndicator(color: Color(0xFF35CA67))
              else if (kIsWeb)
                // Official Google-rendered button for Web (fixes FedCM/CORS warnings)
                SizedBox(
                  height: 50,
                  child: web.renderButton(),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle(),
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_Logo.png',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.login),
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey[300]!),
                      elevation: 0,
                    ),
                  ),
                ),
              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    authState.error.toString(),
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              const Text(
                'By continuing, you agree to our Terms and Conditions',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
