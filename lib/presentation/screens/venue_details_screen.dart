import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_detail_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';

class VenueDetailsScreen extends ConsumerStatefulWidget {
  final String venueId;
  const VenueDetailsScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailsScreen> createState() => _VenueDetailsScreenState();
}

class _VenueDetailsScreenState extends ConsumerState<VenueDetailsScreen> {
  bool _isLocking = false;

  @override
  void initState() {
    super.initState();
    // Reset selection when entering a new venue to avoid Issue #8
    Future.microtask(() {
      ref.read(selectedSlotsProvider.notifier).value = [];
      ref.read(selectedZoneIdProvider.notifier).value = null;
    });
  }

  /// Called when player taps "Book Now".
  /// Locks all selected slots immediately (10-min hold), then navigates to checkout.
  Future<void> _onBookNow() async {
    debugPrint('[_onBookNow] Started');
    final user = ref.read(currentUserProvider);
    if (user == null) {
      debugPrint('[_onBookNow] User is null');
      return;
    }

    final selectedSlots = ref.read(selectedSlotsProvider);
    final venue = ref.read(venueProvider(widget.venueId)).value;

    debugPrint('[_onBookNow] selectedSlots count: ${selectedSlots.length}');
    debugPrint('[_onBookNow] venue is null: ${venue == null}');

    if (selectedSlots.isEmpty || venue == null) {
      debugPrint('[_onBookNow] Returning early: empty slots or null venue');
      return;
    }

    setState(() => _isLocking = true);
    debugPrint('[_onBookNow] Calling lockSlots for user: ${user.id}');

    final locked = await ref
        .read(bookingRepositoryProvider)
        .lockSlots(selectedSlots, user.id);

    debugPrint('[_onBookNow] lockSlots result: $locked');

    if (!mounted) {
      debugPrint('[_onBookNow] Not mounted after lockSlots');
      return;
    }
    setState(() => _isLocking = false);

    if (!locked) {
      debugPrint('[_onBookNow] Lock failed, showing snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('One or more slots were just taken. Please reselect.'),
          backgroundColor: Colors.red,
        ),
      );
      // Clear selection so player picks again
      ref.read(selectedSlotsProvider.notifier).value = [];
      return;
    }

    debugPrint('[_onBookNow] Navigating to checkout');
    context.go(
      '/checkout',
      extra: {
        'venue': venue,
        'slots': selectedSlots,
        'lockedByUserId': user.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueProvider(widget.venueId));
    final zonesAsync = ref.watch(venueZonesProvider(widget.venueId));
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedZoneId = ref.watch(selectedZoneIdProvider);
    final selectedSlots = ref.watch(selectedSlotsProvider);
    final user = ref.watch(currentUserProvider);

    debugPrint(
      '[VenueDetailsScreen] build: user=${user?.id}, slots=${selectedSlots.length}, isLocking=$_isLocking',
    );
    ref.listen(venueZonesProvider(widget.venueId), (prev, next) {
      next.whenData((zones) {
        if (ref.read(selectedZoneIdProvider) == null && zones.isNotEmpty) {
          ref.read(selectedZoneIdProvider.notifier).value = zones.first.id;
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Venue Details')),
      body: venueAsync.when(
        data: (venue) {
          if (venue == null) {
            return const Center(child: Text('Venue not found'));
          }

          // Combine venue images with all zone images
          final List<String> allImages = [...venue.images];
          zonesAsync.whenData((zones) {
            for (final zone in zones) {
              allImages.addAll(zone.images);
            }
          });

          debugPrint(
            '[VenueDetailsScreen] venue: ${venue.name}, total images: ${allImages.length} (venue: ${venue.images.length})',
          );

          return Column(
            children: [
              // Image gallery
              if (allImages.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: allImages.length,
                    itemBuilder: (context, index) {
                      debugPrint(
                        '[VenueDetailsScreen] Loading image[$index]: ${allImages[index]}',
                      );
                      return CachedNetworkImage(
                        imageUrl: allImages[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) {
                          debugPrint(
                            '[VenueDetailsScreen] Error loading image: $error',
                          );
                          return const Icon(Icons.broken_image, size: 60);
                        },
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stadium, size: 60, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        venue.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        venue.location,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

              // Venue info strip
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venue.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            venue.location,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            Text(
                              ' ${venue.rating}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'from ₹${venue.pricePerHour.toStringAsFixed(0)}/hr',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 7-Day Date Picker
              _DatePicker(selectedDate: selectedDate),

              const Divider(height: 1),

              // Zone Selector
              zonesAsync.when(
                data: (zones) {
                  if (zones.isEmpty) return const SizedBox.shrink();
                  return _ZoneSelector(
                    zones: zones,
                    selectedZoneId: selectedZoneId,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Error: $e'),
              ),

              const Divider(height: 1),

              // Slot Grid
              if (selectedZoneId != null)
                Expanded(child: _SlotGrid(zoneId: selectedZoneId))
              else
                const Expanded(
                  child: Center(child: Text('Select a zone to see slots')),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: _StickyFooter(
        selectedSlots: selectedSlots,
        isLocking: _isLocking,
        onBook: _onBookNow,
      ),
    );
  }
}

class _DatePicker extends ConsumerWidget {
  final DateTime selectedDate;
  const _DatePicker({required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).value = date;
              ref.read(selectedSlotsProvider.notifier).value = [];
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300]!,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: zones.map((zone) {
          final isSelected = zone.id == selectedZoneId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(zone.name),
              selected: isSelected,
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

class _SlotGrid extends ConsumerWidget {
  final String zoneId;
  const _SlotGrid({required this.zoneId});

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
          return const Center(child: Text('No slots available for this date.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            final isSelected = selectedSlots.any((s) => s.id == slot.id);
            final isAvailable = slot.status == SlotStatus.available;

            return GestureDetector(
              onTap: isAvailable
                  ? () {
                      final notifier = ref.read(selectedSlotsProvider.notifier);
                      if (isSelected) {
                        notifier.value = selectedSlots
                            .where((s) => s.id != slot.id)
                            .toList();
                      } else {
                        notifier.value = [...selectedSlots, slot];
                      }
                    }
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: !isAvailable
                      ? Colors.grey[200]
                      : isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !isAvailable
                        ? Colors.grey[300]!
                        : Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    DateFormat('hh:mm a').format(slot.startTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: !isAvailable
                          ? Colors.grey[400]
                          : isSelected
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      decoration: !isAvailable
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

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
    final total = selectedSlots.fold(0.0, (sum, s) => sum + s.price);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selectedSlots.length} slot(s) selected',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: isLocking ? null : onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
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
                  : const Text('Book Now'),
            ),
          ],
        ),
      ),
    );
  }
}
