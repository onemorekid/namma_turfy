import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:namma_turfy/presentation/widgets/app_network_image.dart';
import 'package:namma_turfy/presentation/widgets/star_rating_widget.dart';

/// Horizontal venue card used in the home screen list.
///
/// Layout: [120×80 thumbnail] | [name, sports, stars, price, distance]
///                                                       [Book Now badge]
class VenueCardWidget extends ConsumerWidget {
  final Venue venue;
  final double? distanceKm;

  const VenueCardWidget({super.key, required this.venue, this.distanceKm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(venueOffersProvider(venue.ownerId));

    return GestureDetector(
      onTap: () => context.push('/venue/${venue.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.listGap),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: const Border.fromBorderSide(
            BorderSide(color: AppColors.outline),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard, // 5% black
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: venue.images.isNotEmpty
                      ? AppNetworkImage(
                          imageUrl: venue.images.first,
                          width: 120,
                          height: 100,
                          fit: BoxFit.cover,
                          errorWidget: _placeholder(),
                        )
                      : _placeholder(),
                ),
                // Distance chip — top-left on thumbnail
                if (distanceKm != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.onSurface.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${distanceKm!.toStringAsFixed(1)} km',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Info ───────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      venue.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Location
                    Text(
                      venue.location,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Sports tags
                    if (venue.sportsTypes.isNotEmpty)
                      Text(
                        venue.sportsTypes.take(2).join(' · '),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 6),

                    // Stars
                    StarRatingWidget(rating: venue.rating, iconSize: 14),
                    const SizedBox(height: 8),

                    // Price + Book Now
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'From ₹${(venue.minSlotPrice ?? venue.pricePerHour).toStringAsFixed(0)} / hr',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // Book Now badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Book Now',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // F-07: Offers row
                    offersAsync.when(
                      data: (offers) {
                        if (offers.isEmpty) return const SizedBox.shrink();
                        final first = offers.first;
                        final label = offers.length == 1
                            ? '🏷 ${first.code} · ${first.discountType == DiscountType.percentage ? '${first.discountValue.toInt()}% off' : '₹${first.discountValue.toInt()} off'}'
                            : '🏷 ${first.code} +${offers.length - 1} offers';

                        return InkWell(
                          onTap: () {
                            _showOffers(context, offers);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.offer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOffers(BuildContext context, List<Coupon> offers) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Offers', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.md),
              ...offers.map(
                (coupon) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.local_offer_outlined,
                    color: AppColors.offer,
                  ),
                  title: Text(
                    coupon.code,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    coupon.discountType == DiscountType.percentage
                        ? '${coupon.discountValue.toInt()}% off on all bookings'
                        : '₹${coupon.discountValue.toInt()} off on all bookings',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 120,
    height: 100,
    decoration: const BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
    ),
    child: const Icon(Icons.sports_soccer, color: AppColors.primary, size: 36),
  );
}
