import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_detail_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:namma_turfy/presentation/widgets/app_network_image.dart';
import 'package:namma_turfy/presentation/widgets/slot_row_widget.dart';
import 'package:namma_turfy/presentation/widgets/star_rating_widget.dart';

class VenueDetailsScreen extends ConsumerStatefulWidget {
  final String venueId;
  const VenueDetailsScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailsScreen> createState() => _VenueDetailsScreenState();
}

class _VenueDetailsScreenState extends ConsumerState<VenueDetailsScreen> {
  bool _isLocking = false;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(selectedSlotsProvider.notifier).value = [];
      ref.read(selectedZoneIdProvider.notifier).value = null;
    });
  }

  Future<void> _onBookNow() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final selectedSlots = ref.read(selectedSlotsProvider);
    final venue = ref.read(venueProvider(widget.venueId)).value;
    if (selectedSlots.isEmpty || venue == null) return;

    setState(() => _isLocking = true);
    final locked = await ref
        .read(bookingRepositoryProvider)
        .lockSlots(selectedSlots, user.id);

    if (!mounted) return;
    setState(() => _isLocking = false);

    if (!locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('One or more slots were just taken. Please reselect.'),
          backgroundColor: AppColors.error,
        ),
      );
      ref.read(selectedSlotsProvider.notifier).value = [];
      return;
    }
    context.go(
      '/checkout',
      extra: {
        'venue': venue,
        'slots': selectedSlots,
        'lockedByUserId': user.id,
      },
    );
  }

  Future<void> _openMaps(Venue venue) async {
    final query = Uri.encodeComponent(venue.location);
    final lat = venue.latitude;
    final lng = venue.longitude;

    Uri uri;
    if (kIsWeb) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    } else if (Platform.isAndroid) {
      uri = Uri.parse('geo:$lat,$lng?q=$query');
    } else if (Platform.isIOS) {
      uri = Uri.parse('https://maps.apple.com/?q=$query&ll=$lat,$lng');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueProvider(widget.venueId));
    final zonesAsync = ref.watch(venueZonesProvider(widget.venueId));
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedZoneId = ref.watch(selectedZoneIdProvider);
    final selectedSlots = ref.watch(selectedSlotsProvider);

    ref.listen(venueZonesProvider(widget.venueId), (_, next) {
      next.whenData((zones) {
        if (ref.read(selectedZoneIdProvider) == null && zones.isNotEmpty) {
          ref.read(selectedZoneIdProvider.notifier).value = zones.first.id;
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: venueAsync.maybeWhen(
          data: (v) => Text(v?.name ?? 'Venue Details'),
          orElse: () => const Text('Venue Details'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: venueAsync.when(
        data: (venue) {
          if (venue == null) {
            return const Center(child: Text('Venue not found'));
          }

          final allImages = [
            ...venue.images,
            ...zonesAsync.maybeWhen(
              data: (zones) => zones.expand((z) => z.images).toList(),
              orElse: () => <String>[],
            ),
          ];

          return Column(
            children: [
              // ── Image gallery ──────────────────────────────────────────────
              SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    allImages.isNotEmpty
                        ? PageView.builder(
                            controller: _pageController,
                            onPageChanged: (i) =>
                                setState(() => _currentImageIndex = i),
                            itemCount: allImages.length,
                            itemBuilder: (_, i) => AppNetworkImage(
                              imageUrl: allImages[i],
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: AppColors.surfaceVariant,
                                child: const Icon(
                                  Icons.sports_soccer,
                                  size: 60,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceVariant,
                            child: const Center(
                              child: Icon(
                                Icons.stadium,
                                size: 64,
                                color: AppColors.primary,
                              ),
                            ),
                          ),

                    // Dot indicators
                    if (allImages.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: allImages.asMap().entries.map((e) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(
                                  alpha: _currentImageIndex == e.key
                                      ? 0.9
                                      : 0.4,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Venue info strip ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.outline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(venue.name, style: AppTextStyles.titleLarge),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () => _openMaps(venue),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    venue.location,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          StarRatingWidget(rating: venue.rating, iconSize: 16),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'from ₹${venue.pricePerHour.toStringAsFixed(0)}/hr',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // ── 7-Day date picker ──────────────────────────────────────────
              _DatePicker(selectedDate: selectedDate),

              const Divider(height: 1),

              // ── Zone selector ──────────────────────────────────────────────
              zonesAsync.when(
                data: (zones) => zones.isEmpty
                    ? const SizedBox.shrink()
                    : _ZoneSelector(
                        zones: zones,
                        selectedZoneId: selectedZoneId,
                      ),
                loading: () => const LinearProgressIndicator(
                  color: AppColors.primary,
                  minHeight: 2,
                ),
                error: (e, _) => Text('Error: $e'),
              ),

              const Divider(height: 1),

              // ── Slot list ──────────────────────────────────────────────────
              if (selectedZoneId != null)
                Expanded(
                  child: _SlotList(zoneId: selectedZoneId, venue: venue),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      'Select a zone to see slots',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVar,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: _StickyFooter(
        selectedSlots: selectedSlots,
        isLocking: _isLocking,
        onBook: _onBookNow,
      ),
    );
  }
}

// ── 7-Day Date Picker ──────────────────────────────────────────────────────────

class _DatePicker extends ConsumerWidget {
  final DateTime selectedDate;
  const _DatePicker({required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: 7,
        itemBuilder: (_, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          final isToday = index == 0;

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).value = date;
              ref.read(selectedSlotsProvider.notifier).value = [];
            },
            child: Container(
              width: 44,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.outline,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected ? Colors.white : AppColors.onSurfaceVar,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d').format(date),
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isSelected ? Colors.white : AppColors.onSurface,
                    ),
                  ),
                  if (isToday && !isSelected)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Zone Selector ──────────────────────────────────────────────────────────────

class _ZoneSelector extends ConsumerWidget {
  final List<Zone> zones;
  final String? selectedZoneId;
  const _ZoneSelector({required this.zones, required this.selectedZoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: zones.map((zone) {
          final isSelected = zone.id == selectedZoneId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(zone.name),
              selected: isSelected,
              selectedColor: AppColors.primary,
              labelStyle: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
              onSelected: (val) {
                if (val) {
                  ref.read(selectedZoneIdProvider.notifier).value = zone.id;
                  ref.read(selectedSlotsProvider.notifier).value = [];
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Slot List (row-style, replaces old grid) ───────────────────────────────────

class _SlotList extends ConsumerWidget {
  final String zoneId;
  final Venue venue;
  const _SlotList({required this.zoneId, required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final slotsAsync = ref.watch(
      zoneSlotsFamily((zoneId: zoneId, date: selectedDate)),
    );
    final selectedSlots = ref.watch(selectedSlotsProvider);

    return slotsAsync.when(
      data: (slots) {
        if (slots.isEmpty) {
          return Center(
            child: Text(
              'No slots available for this date.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVar,
              ),
            ),
          );
        }

        final sorted = [...slots]
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, index) {
            final slot = sorted[index];
            final isSelected = selectedSlots.any((s) => s.id == slot.id);
            final isPast = slot.startTime.isBefore(DateTime.now());
            final isAvailable = slot.status == SlotStatus.available && !isPast;

            bool isPeak = false;
            final startMinutes =
                slot.startTime.hour * 60 + slot.startTime.minute;
            final morningStart =
                venue.morningPeakStartHour * 60 + venue.morningPeakStartMinute;
            final morningEnd =
                venue.morningPeakEndHour * 60 + venue.morningPeakEndMinute;
            final eveningStart =
                venue.eveningPeakStartHour * 60 + venue.eveningPeakStartMinute;
            final eveningEnd =
                venue.eveningPeakEndHour * 60 + venue.eveningPeakEndMinute;

            if ((startMinutes >= morningStart && startMinutes < morningEnd) ||
                (startMinutes >= eveningStart && startMinutes < eveningEnd)) {
              isPeak = true;
            }

            return SlotRowWidget(
              slot: slot,
              isSelected: isSelected,
              isPeak: isPeak,
              onTap: isAvailable
                  ? () {
                      final notifier = ref.read(selectedSlotsProvider.notifier);
                      notifier.value = isSelected
                          ? selectedSlots.where((s) => s.id != slot.id).toList()
                          : [...selectedSlots, slot];
                    }
                  : null,
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Sticky footer ──────────────────────────────────────────────────────────────

class _StickyFooter extends StatelessWidget {
  final List<Slot> selectedSlots;
  final bool isLocking;
  final VoidCallback onBook;
  const _StickyFooter({
    required this.selectedSlots,
    required this.isLocking,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedSlots.isEmpty) return const SizedBox.shrink();
    final total = selectedSlots.fold(0.0, (s, slot) => s + slot.price);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.ctaBottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFloat,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selectedSlots.length} slot${selectedSlots.length > 1 ? 's' : ''} selected',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: AppTextStyles.priceTotal,
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLocking ? null : onBook,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLocking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Book Now',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
