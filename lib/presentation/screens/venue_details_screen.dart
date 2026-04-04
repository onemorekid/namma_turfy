import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/presentation/providers/venue_detail_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';

class VenueDetailsScreen extends ConsumerWidget {
  final String venueId;
  const VenueDetailsScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueProvider(venueId));
    final zonesAsync = ref.watch(venueZonesProvider(venueId));
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedZoneId = ref.watch(selectedZoneIdProvider);
    final selectedSlots = ref.watch(selectedSlotsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Venue Details')),
      body: venueAsync.when(
        data: (venue) {
          if (venue == null) {
            return const Center(child: Text('Venue not found'));
          }
          return Column(
            children: [
              // Image gallery
              if (venue.images.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: venue.images.length,
                    itemBuilder: (context, index) => CachedNetworkImage(
                      imageUrl: venue.images[index],
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image, size: 60),
                    ),
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
                  Future.microtask(() {
                    if (selectedZoneId == null && zones.isNotEmpty) {
                      ref.read(selectedZoneIdProvider.notifier).value =
                          zones.first.id;
                    }
                  });
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
        onBook: () {
          if (venueAsync.value == null) return;
          context.push(
            '/checkout',
            extra: {'venue': venueAsync.value!, 'slots': selectedSlots},
          );
        },
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
    final slotsAsync = ref.watch(playerZoneSlotsProvider(zoneId));
    final selectedSlots = ref.watch(selectedSlotsProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return slotsAsync.when(
      data: (allSlots) {
        final slots = allSlots
            .where((s) => DateUtils.isSameDay(s.startTime, selectedDate))
            .toList();

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
  final VoidCallback onBook;
  const _StickyFooter({required this.selectedSlots, required this.onBook});

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
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: const Text('Book Now'),
            ),
          ],
        ),
      ),
    );
  }
}
