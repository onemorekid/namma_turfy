import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiptScreen extends ConsumerWidget {
  final String bookingId;
  const ReceiptScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: bookingAsync.when(
        data: (booking) {
          if (booking == null) {
            return const Center(
              child: Text(
                'Booking not found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          final venueAsync = ref.watch(venueProvider(booking.venueId));

          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Dark green header ──────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        // Checkmark circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: AppColors.primary,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Booking Confirmed!',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          booking.venueName ?? '',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (booking.venueLocation != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.white60,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                booking.venueLocation!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Show this QR code at the venue',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // QR code
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: QrImageView(
                            data:
                                'https://nammaturfy.web.app/verify/${booking.id}',
                            version: QrVersions.auto,
                            size: 180,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── White card section ─────────────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      // Booking details
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.outline),
                          ),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            _ReceiptRow(
                              label: 'Booking ID',
                              value:
                                  '#${booking.id.substring(booking.id.length > 6 ? booking.id.length - 6 : 0)}',
                            ),
                            _ReceiptRow(
                              label: 'Date',
                              value: DateFormat(
                                'EEE, MMM dd, yyyy',
                              ).format(booking.startTime),
                            ),
                            _ReceiptRow(
                              label: 'Time',
                              value:
                                  '${DateFormat('hh:mm a').format(booking.startTime)} – '
                                  '${DateFormat('hh:mm a').format(booking.endTime)}',
                            ),
                            if (booking.sportType != null)
                              _ReceiptRow(
                                label: 'Sport',
                                value: booking.sportType!,
                              ),
                            if (booking.zoneName != null)
                              _ReceiptRow(
                                label: 'Zone',
                                value: booking.zoneName!,
                              ),
                            _ReceiptRow(
                              label: 'Slots Booked',
                              value: '${booking.slotIds.length}',
                            ),
                            if (booking.couponCode != null)
                              _ReceiptRow(
                                label: 'Promo Applied',
                                value: booking.couponCode!,
                                valueColor: AppColors.primary,
                              ),
                            _ReceiptRow(
                              label: 'Payment',
                              value: 'Online (Razorpay)',
                            ),
                            const Divider(height: AppSpacing.md),
                            _ReceiptRow(
                              label: 'Total Paid',
                              value:
                                  '₹${(booking.discountedPrice ?? booking.totalPrice).toStringAsFixed(0)}',
                              isBold: true,
                            ),
                          ],
                        ),
                      ),

                      // Venue instructions, policy, rules
                      venueAsync.when(
                        data: (venue) => venue == null
                            ? const SizedBox.shrink()
                            : _VenueInfoSection(venue: venue),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => context.go('/'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                backgroundColor: AppColors.primary,
                              ),
                              child: Text(
                                'Home',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.push('/my-bookings'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                foregroundColor: AppColors.primary,
                              ),
                              child: Text(
                                'My Bookings',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

// ── Venue info section ────────────────────────────────────────────────────────

class _VenueInfoSection extends StatelessWidget {
  final Venue venue;
  const _VenueInfoSection({required this.venue});

  @override
  Widget build(BuildContext context) {
    final hasAny =
        venue.generalInstructions != null ||
        venue.cancellationPolicy != null ||
        venue.rules.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (venue.generalInstructions != null)
            _InfoCard(
              icon: Icons.info_outline,
              title: 'General Instructions',
              body: venue.generalInstructions!,
            ),
          if (venue.cancellationPolicy != null)
            _InfoCard(
              icon: Icons.cancel_outlined,
              title: 'Cancellation Policy',
              body: venue.cancellationPolicy!,
            ),
          if (venue.rules.isNotEmpty) _RulesCard(rules: venue.rules),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.onSurfaceVar),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTextStyles.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  final List<String> rules;
  const _RulesCard({required this.rules});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule, size: 16, color: AppColors.onSurfaceVar),
              const SizedBox(width: AppSpacing.sm),
              Text('Venue Rules', style: AppTextStyles.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurfaceVar,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rule,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Receipt row ────────────────────────────────────────────────────────────────

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVar,
            ),
          ),
          Text(
            value,
            style: isBold
                ? AppTextStyles.titleMedium.copyWith(
                    color: valueColor ?? AppColors.onSurface,
                  )
                : AppTextStyles.bodyMedium.copyWith(
                    color: valueColor ?? AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ],
      ),
    );
  }
}
