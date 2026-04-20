import 'package:flutter/material.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';

/// Displays a row of star icons with an optional numeric label and review count.
class StarRatingWidget extends StatelessWidget {
  final double rating;
  final int? reviewCount;

  /// Icon size: 16 for list cards, 20 for detail screens.
  final double iconSize;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.reviewCount,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Star icons
        for (int i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Icon(
            i < fullStars
                ? Icons.star
                : (i == fullStars && hasHalf)
                    ? Icons.star_half
                    : Icons.star_border,
            size: iconSize,
            color: i < fullStars || (i == fullStars && hasHalf)
                ? AppColors.star
                : AppColors.outlineVariant,
          ),
        ],
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '( $reviewCount Reviews )',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ],
    );
  }
}
