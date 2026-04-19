import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/core/services/storage_service.dart';
import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:namma_turfy/presentation/widgets/app_drawer.dart';
import 'package:namma_turfy/presentation/widgets/app_network_image.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final venueAsync = ref.watch(ownerVenueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: venueAsync.when(
        data: (venue) {
          if (venue == null) {
            return Center(
              child: ElevatedButton.icon(
                onPressed: () => _showCreateVenueDialog(context, ref, user!.id),
                icon: const Icon(Icons.add),
                label: const Text('Create Venue'),
              ),
            );
          }
          return IndexedStack(
            index: _selectedIndex,
            children: [
              _VenueManager(venue: venue),
              _BookingsList(venueId: venue.id),
              _CouponsManager(venue: venue),
              _EarningsDashboard(venue: venue),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF35CA67),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.stadium), label: 'Venue'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Bookings'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer),
            label: 'Coupons',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Earnings',
          ),
        ],
      ),
    );
  }

  void _showCreateVenueDialog(
    BuildContext context,
    WidgetRef ref,
    String ownerId,
  ) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    List<XFile> pendingImages = [];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Venue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Venue Name'),
                ),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (Area)',
                  ),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price/hr (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _ImagePickerSection(
                  existingUrls: const [],
                  pendingImages: pendingImages,
                  onPickImages: () async {
                    final picked = await StorageService.pickImages();
                    if (picked.isNotEmpty) {
                      setDialogState(
                        () => pendingImages = [...pendingImages, ...picked],
                      );
                    }
                  },
                  onRemovePending: (i) => setDialogState(
                    () => pendingImages = [...pendingImages]..removeAt(i),
                  ),
                  onRemoveExisting: null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        final venueId =
                            'venue_${DateTime.now().millisecondsSinceEpoch}';
                        final uploadedUrls =
                            await StorageService.uploadVenueImages(
                              venueId,
                              pendingImages,
                            );
                        final newVenue = Venue(
                          id: venueId,
                          ownerId: ownerId,
                          name: nameController.text,
                          location: locationController.text,
                          city: 'Vijayapura',
                          latitude: 17.3297,
                          longitude: 75.7181,
                          type: 'Cricket',
                          rating: 4.0,
                          description: descController.text,
                          pricePerHour:
                              double.tryParse(priceController.text) ?? 0.0,
                          sportsTypes: const ['Cricket'],
                          availableHours: const ['06:00', '22:00'],
                          images: uploadedUrls,
                        );
                        await ref
                            .read(venueRepositoryProvider)
                            .saveVenue(newVenue);
                        ref.invalidate(ownerVenueProvider);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueManager extends ConsumerWidget {
  final Venue venue;
  const _VenueManager({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(venueZonesProvider(venue.id));
    final selectedDate = ref.watch(ownerSelectedDateProvider);

    return Column(
      children: [
        ListTile(
          title: Text(
            venue.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text(
            '${venue.location} • ₹${venue.pricePerHour.toStringAsFixed(0)}/hr',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: 'Edit Venue',
                onPressed: () => _showEditVenueDialog(context, ref, venue),
              ),
              IconButton(
                icon: const Icon(Icons.add_box),
                tooltip: 'Add Zone',
                onPressed: () => _showAddZoneDialog(context, ref, venue.id),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        _OwnerDatePicker(selectedDate: selectedDate),
        const Divider(height: 1),
        Expanded(
          child: zonesAsync.when(
            data: (zones) {
              if (zones.isEmpty) {
                return const Center(
                  child: Text(
                    'No zones yet. Add a pitch or court to get started!',
                  ),
                );
              }
              return ListView.builder(
                itemCount: zones.length,
                itemBuilder: (context, index) => _ZoneItem(zone: zones[index]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  void _showEditVenueDialog(BuildContext context, WidgetRef ref, Venue venue) {
    final nameController = TextEditingController(text: venue.name);
    final locationController = TextEditingController(text: venue.location);
    final descController = TextEditingController(text: venue.description);
    final priceController = TextEditingController(
      text: venue.pricePerHour.toString(),
    );
    List<String> existingUrls = List.from(venue.images);
    List<XFile> pendingImages = [];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Venue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price/hr (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _ImagePickerSection(
                  existingUrls: existingUrls,
                  pendingImages: pendingImages,
                  onPickImages: () async {
                    final picked = await StorageService.pickImages();
                    if (picked.isNotEmpty) {
                      setDialogState(
                        () => pendingImages = [...pendingImages, ...picked],
                      );
                    }
                  },
                  onRemovePending: (i) => setDialogState(
                    () => pendingImages = [...pendingImages]..removeAt(i),
                  ),
                  onRemoveExisting: (i) async {
                    await StorageService.deleteImage(existingUrls[i]);
                    setDialogState(
                      () => existingUrls = [...existingUrls]..removeAt(i),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        final newUrls = await StorageService.uploadVenueImages(
                          venue.id,
                          pendingImages,
                        );
                        final updated = venue.copyWith(
                          name: nameController.text,
                          location: locationController.text,
                          description: descController.text,
                          pricePerHour:
                              double.tryParse(priceController.text) ??
                              venue.pricePerHour,
                          images: [...existingUrls, ...newUrls],
                        );
                        await ref
                            .read(venueRepositoryProvider)
                            .saveVenue(updated);
                        ref.invalidate(ownerVenueProvider);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddZoneDialog(BuildContext context, WidgetRef ref, String venueId) {
    final nameController = TextEditingController();
    List<XFile> pendingImages = [];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Zone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zone Name (e.g. Pitch A)',
                  ),
                ),
                const SizedBox(height: 16),
                _ImagePickerSection(
                  existingUrls: const [],
                  pendingImages: pendingImages,
                  onPickImages: () async {
                    final picked = await StorageService.pickImages();
                    if (picked.isNotEmpty) {
                      setDialogState(
                        () => pendingImages = [...pendingImages, ...picked],
                      );
                    }
                  },
                  onRemovePending: (i) => setDialogState(
                    () => pendingImages = [...pendingImages]..removeAt(i),
                  ),
                  onRemoveExisting: null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        final zoneId =
                            'zone_${DateTime.now().millisecondsSinceEpoch}';
                        final imageUrls = await StorageService.uploadZoneImages(
                          zoneId,
                          pendingImages,
                        );
                        final newZone = Zone(
                          id: zoneId,
                          venueId: venueId,
                          name: nameController.text,
                          type: 'Cricket',
                          images: imageUrls,
                        );
                        await ref
                            .read(venueRepositoryProvider)
                            .saveZone(newZone);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneItem extends ConsumerWidget {
  final Zone zone;
  const _ZoneItem({required this.zone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(ownerSelectedDateProvider);
    final slotsAsync = ref.watch(
      zoneSlotsFamily((zoneId: zone.id, date: selectedDate)),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              zone.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _showBulkGenerateDialog(context, ref, zone.id),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Bulk', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final selectedDate = ref.read(ownerSelectedDateProvider);
                    final now = DateTime.now();
                    final startTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      now.hour,
                      now.minute,
                    );
                    final newSlot = Slot(
                      id: 'slot_${zone.id}_${startTime.millisecondsSinceEpoch}',
                      zoneId: zone.id,
                      startTime: startTime,
                      endTime: startTime.add(const Duration(minutes: 60)),
                      price: 500.0,
                      status: SlotStatus.available,
                    );
                    ref.read(venueRepositoryProvider).saveSlot(newSlot);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Slot added!')),
                    );
                  },
                  icon: const Icon(Icons.add_alarm, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(60, 32),
                  ),
                ),
              ],
            ),
          ),
          slotsAsync.when(
            data: (slots) => slots.isEmpty
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'No slots yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: slots.length,
                      itemBuilder: (context, index) {
                        final slot = slots[index];
                        return GestureDetector(
                          onTap: () {
                            final updated = slot.copyWith(
                              status: slot.status == SlotStatus.available
                                  ? SlotStatus.booked
                                  : SlotStatus.available,
                            );
                            ref.read(venueRepositoryProvider).saveSlot(updated);
                          },
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Slot?'),
                                content: Text(
                                  'Are you sure you want to delete the slot at ${DateFormat('hh:mm a').format(slot.startTime)}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ref
                                          .read(venueRepositoryProvider)
                                          .deleteSlot(slot.id);
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: slot.status == SlotStatus.available
                                      ? Colors.green[100]
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: slot.status == SlotStatus.available
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                child: Text(
                                  DateFormat('hh:mm a').format(slot.startTime),
                                  style: TextStyle(
                                    fontSize: 10,
                                    decoration:
                                        slot.status != SlotStatus.available
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    ref
                                        .read(venueRepositoryProvider)
                                        .deleteSlot(slot.id);
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cancel,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (e, st) => Text('Error: $e'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showBulkGenerateDialog(
    BuildContext context,
    WidgetRef ref,
    String zoneId,
  ) {
    final initialDate = ref.read(ownerSelectedDateProvider);
    DateTime startDate = initialDate;
    DateTime endDate = initialDate;
    TimeOfDay startTime = const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 22, minute: 0);
    final priceController = TextEditingController(text: '500');
    final durationController = TextEditingController(text: '60');
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk Generate Slots'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Date Range'),
                  subtitle: Text(
                    '${DateFormat('dd MMM').format(startDate)} – ${DateFormat('dd MMM').format(endDate)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: DateTimeRange(
                        start: startDate,
                        end: endDate,
                      ),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked.start;
                        endDate = picked.end;
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('Start Time'),
                  subtitle: Text(startTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (picked != null) {
                      setDialogState(() => startTime = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Time'),
                  subtitle: Text(endTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                    );
                    if (picked != null) {
                      setDialogState(() => endTime = picked);
                    }
                  },
                ),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Slot Duration (mins)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price per Slot (₹)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isGenerating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isGenerating
                  ? null
                  : () async {
                      final slots = <Slot>[];
                      final duration =
                          int.tryParse(durationController.text) ?? 60;
                      final price =
                          double.tryParse(priceController.text) ?? 500.0;

                      for (
                        int i = 0;
                        i <= endDate.difference(startDate).inDays;
                        i++
                      ) {
                        final currentDate = startDate.add(Duration(days: i));
                        DateTime current = DateTime(
                          currentDate.year,
                          currentDate.month,
                          currentDate.day,
                          startTime.hour,
                          startTime.minute,
                        );
                        final dayEnd = DateTime(
                          currentDate.year,
                          currentDate.month,
                          currentDate.day,
                          endTime.hour,
                          endTime.minute,
                        );
                        while (current.isBefore(dayEnd)) {
                          final slotEnd = current.add(
                            Duration(minutes: duration),
                          );
                          slots.add(
                            Slot(
                              id: 'slot_${zoneId}_${current.millisecondsSinceEpoch}',
                              zoneId: zoneId,
                              startTime: current,
                              endTime: slotEnd,
                              price: price,
                              status: SlotStatus.available,
                            ),
                          );
                          current = slotEnd;
                        }
                      }

                      if (slots.isEmpty) {
                        Navigator.pop(context);
                        return;
                      }

                      setDialogState(() => isGenerating = true);
                      try {
                        await ref
                            .read(venueRepositoryProvider)
                            .bulkSaveSlots(slots);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isGenerating = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to generate slots: ${e.toString()}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsList extends ConsumerWidget {
  final String venueId;
  const _BookingsList({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(venueBookingsStreamProvider(venueId));

    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return const Center(child: Text('No bookings yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final shortId = booking.id.length > 6
                ? booking.id.substring(booking.id.length - 6)
                : booking.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                isThreeLine: true,
                title: Text(
                  '${booking.playerName ?? "Player"} • Booking #$shortId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('EEE, MMM dd').format(booking.startTime)} • '
                      '${DateFormat('hh:mm a').format(booking.startTime)} - ${DateFormat('hh:mm a').format(booking.endTime)}',
                    ),
                    Text(
                      '${booking.sportType ?? ""} • ${booking.zoneName ?? "Zone"} • ${booking.slotIds.length} slot(s)',
                    ),
                    if (booking.playerPhone != null)
                      Text('Contact: ${booking.playerPhone}'),
                  ],
                ),
                trailing: Text(
                  '₹${(booking.discountedPrice ?? booking.totalPrice).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
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

class _CouponsManager extends ConsumerWidget {
  final Venue venue;
  const _CouponsManager({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(ownerCouponsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Promo Codes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _showCreateCouponDialog(context, ref, venue.ownerId),
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: couponsAsync.when(
              data: (coupons) {
                if (coupons.isEmpty) {
                  return const Center(child: Text('No active coupons.'));
                }
                return ListView.builder(
                  itemCount: coupons.length,
                  itemBuilder: (context, index) {
                    final coupon = coupons[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          coupon.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        subtitle: Text(
                          '${coupon.discountType == DiscountType.percentage ? '${coupon.discountValue.toStringAsFixed(0)}% Off' : '₹${coupon.discountValue.toStringAsFixed(0)} Flat'} '
                          '• Valid till ${DateFormat('dd MMM').format(coupon.validTo)}'
                          '${coupon.restrictedEmails != null && coupon.restrictedEmails!.isNotEmpty ? ' • ${coupon.restrictedEmails!.length} users' : ''}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => ref
                              .read(venueRepositoryProvider)
                              .deleteCoupon(coupon.id),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCouponDialog(
    BuildContext context,
    WidgetRef ref,
    String ownerId,
  ) {
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    final emailsController = TextEditingController();
    final limitController = TextEditingController(text: '100');
    DiscountType selectedType = DiscountType.percentage;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Promo Code (e.g. SAVE20)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Type: '),
                    ChoiceChip(
                      label: const Text('%'),
                      selected: selectedType == DiscountType.percentage,
                      onSelected: (_) => setDialogState(
                        () => selectedType = DiscountType.percentage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Flat'),
                      selected: selectedType == DiscountType.flat,
                      onSelected: (_) => setDialogState(
                        () => selectedType = DiscountType.flat,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: selectedType == DiscountType.percentage
                        ? 'Percentage Value'
                        : 'Flat Amount (₹)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: limitController,
                  decoration: const InputDecoration(labelText: 'Usage Limit'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Valid Until'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: emailsController,
                  decoration: const InputDecoration(
                    labelText: 'Restrict to Emails (Optional)',
                    hintText: 'user1@email.com, user2@email.com',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final emails = emailsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final coupon = Coupon(
                  id: 'cpn_${DateTime.now().millisecondsSinceEpoch}',
                  ownerId: ownerId,
                  code: codeController.text.toUpperCase(),
                  discountType: selectedType,
                  discountValue: double.tryParse(valueController.text) ?? 0.0,
                  validTo: selectedDate,
                  usageLimit: int.tryParse(limitController.text) ?? 100,
                  restrictedEmails: emails.isEmpty ? null : emails,
                );
                ref.read(venueRepositoryProvider).saveCoupon(coupon);
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsDashboard extends ConsumerWidget {
  final Venue venue;
  const _EarningsDashboard({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(venueBookingsStreamProvider(venue.id));

    return bookingsAsync.when(
      data: (bookings) {
        final totalBookings = bookings.length;
        final netRevenue = bookings.fold(
          0.0,
          (sum, b) => sum + (b.discountedPrice ?? b.totalPrice),
        );
        final avgBooking = totalBookings > 0 ? netRevenue / totalBookings : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Overview',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total Bookings',
                      value: '$totalBookings',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Net Revenue',
                      value: '₹${netRevenue.toStringAsFixed(0)}',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(
                label: 'Avg Booking Value',
                value: '₹${avgBooking.toStringAsFixed(0)}',
                color: Colors.orange,
              ),
              const SizedBox(height: 32),
              const Text(
                'Recent Transactions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (bookings.isEmpty)
                const Text(
                  'No transactions yet.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Card(
                  child: Column(
                    children: bookings.take(5).map((b) {
                      final shortId = b.id.length > 6
                          ? b.id.substring(b.id.length - 6)
                          : b.id;
                      return ListTile(
                        title: Text('Booking #$shortId'),
                        subtitle: Text(
                          b.paymentMethod == PaymentMethod.digital
                              ? 'Digital Payment'
                              : 'Pay at Venue',
                        ),
                        trailing: Text(
                          '+ ₹${(b.discountedPrice ?? b.totalPrice).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerDatePicker extends ConsumerWidget {
  final DateTime selectedDate;
  const _OwnerDatePicker({required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 14, // Allow 2 weeks for owners
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          return GestureDetector(
            onTap: () {
              ref.read(ownerSelectedDateProvider.notifier).value = date;
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF35CA67) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF35CA67)
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

/// Reusable image picker section for dialogs.
/// Shows existing URL thumbnails + pending XFile thumbnails + add button.
class _ImagePickerSection extends StatelessWidget {
  final List<String> existingUrls;
  final List<XFile> pendingImages;
  final VoidCallback onPickImages;
  final void Function(int index)? onRemovePending;
  final void Function(int index)? onRemoveExisting;

  const _ImagePickerSection({
    required this.existingUrls,
    required this.pendingImages,
    required this.onPickImages,
    this.onRemovePending,
    this.onRemoveExisting,
  });

  @override
  Widget build(BuildContext context) {
    final hasImages = existingUrls.isNotEmpty || pendingImages.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Photos',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onPickImages,
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Add Photos'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        if (hasImages)
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Existing URLs
                for (int i = 0; i < existingUrls.length; i++)
                  _ImageThumb(
                    onRemove: onRemoveExisting != null
                        ? () => onRemoveExisting!(i)
                        : null,
                    child: AppNetworkImage(
                      imageUrl: existingUrls[i],
                      fit: BoxFit.cover,
                      errorWidget: const Icon(Icons.broken_image),
                    ),
                  ),
                // Pending (local) images
                for (int i = 0; i < pendingImages.length; i++)
                  _ImageThumb(
                    onRemove: onRemovePending != null
                        ? () => onRemovePending!(i)
                        : null,
                    child: FutureBuilder<Uint8List>(
                      future: pendingImages[i].readAsBytes(),
                      builder: (ctx, snap) => snap.hasData
                          ? Image.memory(snap.data!, fit: BoxFit.cover)
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          )
        else
          Container(
            height: 70,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No photos yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRemove;

  const _ImageThumb({required this.child, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 80, height: 80, child: child),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
