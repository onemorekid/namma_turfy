import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-bleed stadium background ─────────────────────────────────
          Image.network(
            'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=1200',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppColors.primaryDark),
          ),

          // ── Dark overlay (55% opacity) ────────────────────────────────────
          Container(color: Colors.black.withValues(alpha: 0.55)),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo + app name
                  const Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Namma Turfy',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Book your favorite sports arena in seconds',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 4),

                  // Buttons
                  if (authState.isLoading)
                    const CircularProgressIndicator(color: AppColors.primary)
                  else ...[
                    // Login — green filled
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                        icon: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_Logo.png',
                          height: 22,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.login, color: Colors.white),
                        ),
                        label: Text(
                          'Continue with Google',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (authState.hasError) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        authState.error.toString(),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'By continuing, you agree to our Terms and Conditions',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
