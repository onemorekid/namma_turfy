import 'package:flutter/material.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';

/// Dismissible offer / promo banner shown on the home screen.
class OfferBannerWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onDismiss;

  const OfferBannerWidget({
    super.key,
    this.title = 'Offers Available!',
    this.subtitle = 'Book slots during off-peak hours and save up to 30%',
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.offerBg,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
            BorderSide(color: AppColors.offer),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: AppColors.offer, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.offer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.onSurfaceVar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
