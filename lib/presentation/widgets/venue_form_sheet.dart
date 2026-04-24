import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:namma_turfy/core/services/storage_service.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:namma_turfy/presentation/widgets/app_network_image.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class VenueFormSheet extends ConsumerStatefulWidget {
  final Venue? venue;
  final String ownerId;

  const VenueFormSheet({super.key, this.venue, required this.ownerId});

  @override
  ConsumerState<VenueFormSheet> createState() => _VenueFormSheetState();
}

class _VenueFormSheetState extends ConsumerState<VenueFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _locationController;

  String _selectedType = 'Football';
  List<String> _selectedSports = [];

  double _lat = 17.3297;
  double _lng = 75.7181;
  String _city = 'Vijayapura';
  bool _locationConfirmed = false;

  List<String> _existingImages = [];
  final List<XFile> _pendingImages = [];

  TimeOfDay _openTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);

  bool _morningPeakEnabled = true;
  TimeOfDay _morningPeakStart = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _morningPeakEnd = const TimeOfDay(hour: 10, minute: 0);

  bool _eveningPeakEnabled = true;
  TimeOfDay _eveningPeakStart = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _eveningPeakEnd = const TimeOfDay(hour: 22, minute: 0);

  double _peakMultiplier = 1.2;

  late TextEditingController _instrController;
  late TextEditingController _cancelController;
  List<String> _rules = [];

  bool _isSaving = false;
  final MapController _mapController = MapController();

  final List<String> _venueTypes = [
    'Football',
    'Cricket',
    'Badminton',
    'Tennis',
    'Multi-sport',
  ];
  final List<String> _sportsOptions = [
    'Football',
    'Cricket',
    'Badminton',
    'Tennis',
    'Volleyball',
    'Basketball',
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.venue;
    _nameController = TextEditingController(text: v?.name ?? '');
    _descController = TextEditingController(text: v?.description ?? '');
    _priceController = TextEditingController(
      text: v?.pricePerHour.toString() ?? '',
    );
    _locationController = TextEditingController(text: v?.location ?? '');

    if (v != null) {
      _selectedType = v.type;
      _selectedSports = List.from(v.sportsTypes);
      _lat = v.latitude;
      _lng = v.longitude;
      _city = v.city;
      _locationConfirmed = true;
      _existingImages = List.from(v.images);

      if (v.openTimeHour != null) {
        _openTime = TimeOfDay(
          hour: v.openTimeHour!,
          minute: v.openTimeMinute ?? 0,
        );
      }
      if (v.closeTimeHour != null) {
        _closeTime = TimeOfDay(
          hour: v.closeTimeHour!,
          minute: v.closeTimeMinute ?? 0,
        );
      }

      _morningPeakStart = TimeOfDay(
        hour: v.morningPeakStartHour,
        minute: v.morningPeakStartMinute,
      );
      _morningPeakEnd = TimeOfDay(
        hour: v.morningPeakEndHour,
        minute: v.morningPeakEndMinute,
      );
      _eveningPeakStart = TimeOfDay(
        hour: v.eveningPeakStartHour,
        minute: v.eveningPeakStartMinute,
      );
      _eveningPeakEnd = TimeOfDay(
        hour: v.eveningPeakEndHour,
        minute: v.eveningPeakEndMinute,
      );
      _peakMultiplier = v.peakMultiplier;

      _instrController = TextEditingController(
        text: v.generalInstructions ?? '',
      );
      _cancelController = TextEditingController(
        text: v.cancellationPolicy ?? '',
      );
      _rules = List.from(v.rules);
    } else {
      _instrController = TextEditingController();
      _cancelController = TextEditingController();
      _determineInitialLocation();
    }
  }

  Future<void> _determineInitialLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
      _mapController.move(LatLng(_lat, _lng), 15);
      _reverseGeocode(_lat, _lng);
    } catch (e) {
      // Fallback to default
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _locationController.text =
              '${p.name}, ${p.subLocality}, ${p.locality}';
          _city = p.locality ?? 'Vijayapura';
          _locationConfirmed = true;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'countrycodes': 'in',
        },
      );

      if (response.data is List && (response.data as List).isNotEmpty) {
        final first = response.data[0];
        final lat = double.parse(first['lat']);
        final lon = double.parse(first['lon']);
        setState(() {
          _lat = lat;
          _lng = lon;
          _locationController.text = first['display_name'];
          _locationConfirmed = true;
        });
        _mapController.move(LatLng(lat, lon), 15);
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    widget.venue == null ? 'Create Venue' : 'Edit Venue',
                    style: AppTextStyles.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _sectionHeader('1. Basic Info'),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Venue Name*',
                      ),
                      maxLength: 80,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: _venueTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedType = v!),
                      decoration: const InputDecoration(
                        labelText: 'Venue Type*',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Sports Offered*',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: _sportsOptions.map((s) {
                        final isSelected = _selectedSports.contains(s);
                        return FilterChip(
                          label: Text(s),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedSports.add(s);
                              } else {
                                _selectedSports.remove(s);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Description*',
                      ),
                      maxLines: 3,
                      maxLength: 300,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _sectionHeader('2. Location'),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Search Location*',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () =>
                              _searchLocation(_locationController.text),
                        ),
                      ),
                      onSubmitted: _searchLocation,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(_lat, _lng),
                            initialZoom: 15,
                            onTap: (tapPos, point) {
                              setState(() {
                                _lat = point.latitude;
                                _lng = point.longitude;
                              });
                              _reverseGeocode(_lat, _lng);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.nammaturfy.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_lat, _lng),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (!_locationConfirmed)
                      const Text(
                        'Please confirm location by searching or tapping map',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),

                    const SizedBox(height: AppSpacing.lg),
                    _sectionHeader('3. Photos (At least 1 required)'),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: const Icon(
                                Icons.add_a_photo,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          ..._existingImages.asMap().entries.map(
                            (e) => _imageThumb(
                              child: AppNetworkImage(
                                imageUrl: e.value,
                                fit: BoxFit.cover,
                              ),
                              onRemove: () => setState(
                                () => _existingImages.removeAt(e.key),
                              ),
                            ),
                          ),
                          ..._pendingImages.asMap().entries.map(
                            (e) => _imageThumb(
                              child: FutureBuilder<Uint8List>(
                                future: e.value.readAsBytes(),
                                builder: (context, snap) => snap.hasData
                                    ? Image.memory(
                                        snap.data!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                              ),
                              onRemove: () => setState(
                                () => _pendingImages.removeAt(e.key),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _sectionHeader('4. Pricing & Hours'),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Base Price per Hour (₹)*',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if ((double.tryParse(v) ?? 0) <= 0) {
                          return 'Must be > 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _timeField(
                            'Open Time',
                            _openTime,
                            (t) => setState(() => _openTime = t),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _timeField(
                            'Close Time',
                            _closeTime,
                            (t) => setState(() => _closeTime = t),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Peak Hours',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _peakRow(
                      'Morning Peak',
                      _morningPeakEnabled,
                      _morningPeakStart,
                      _morningPeakEnd,
                      (val) => setState(() => _morningPeakEnabled = val),
                      (t) => setState(() => _morningPeakStart = t),
                      (t) => setState(() => _morningPeakEnd = t),
                    ),
                    _peakRow(
                      'Evening Peak',
                      _eveningPeakEnabled,
                      _eveningPeakStart,
                      _eveningPeakEnd,
                      (val) => setState(() => _eveningPeakEnabled = val),
                      (t) => setState(() => _eveningPeakStart = t),
                      (t) => setState(() => _eveningPeakEnd = t),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Text('Peak Multiplier: '),
                        DropdownButton<double>(
                          value: _peakMultiplier,
                          items: [1.1, 1.2, 1.3, 1.4, 1.5]
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('${m}x'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _peakMultiplier = v!),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _sectionHeader('5. Policies'),
                    TextFormField(
                      controller: _instrController,
                      decoration: const InputDecoration(
                        labelText: 'General Instructions',
                      ),
                      maxLines: 2,
                    ),
                    TextFormField(
                      controller: _cancelController,
                      decoration: const InputDecoration(
                        labelText: 'Cancellation Policy',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Rules',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._rules.map(
                          (r) => Chip(
                            label: Text(r),
                            onDeleted: () => setState(() => _rules.remove(r)),
                          ),
                        ),
                        ActionChip(
                          label: const Text('+ Add Rule'),
                          onPressed: _addRule,
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            // Footer Action
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.venue == null
                              ? 'Create Venue'
                              : 'Save Changes',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        title,
        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
      ),
    );
  }

  Widget _timeField(
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onSelected,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(time.format(context)),
      ),
    );
  }

  Widget _peakRow(
    String label,
    bool enabled,
    TimeOfDay start,
    TimeOfDay end,
    Function(bool) onToggle,
    Function(TimeOfDay) onStart,
    Function(TimeOfDay) onEnd,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Switch(value: enabled, onChanged: onToggle),
          ],
        ),
        if (enabled)
          Row(
            children: [
              Expanded(child: _timeField('Start', start, onStart)),
              const SizedBox(width: 8),
              Expanded(child: _timeField('End', end, onEnd)),
            ],
          ),
      ],
    );
  }

  Widget _imageThumb({required Widget child, required VoidCallback onRemove}) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.expand(child: child),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final picked = await StorageService.pickImages();
    if (picked.isNotEmpty) {
      setState(() => _pendingImages.addAll(picked));
    }
  }

  void _addRule() async {
    final controller = TextEditingController();
    final rule = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Rule'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (rule != null && rule.isNotEmpty) {
      setState(() => _rules.add(rule));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one sport')),
      );
      return;
    }
    if (!_locationConfirmed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please confirm location')));
      return;
    }
    if (_existingImages.isEmpty && _pendingImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one photo')));
      return;
    }

    // Check operating hours: close > open
    final openMinutes = _openTime.hour * 60 + _openTime.minute;
    final closeMinutes = _closeTime.hour * 60 + _closeTime.minute;
    if (closeMinutes <= openMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Close time must be after open time')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final id =
          widget.venue?.id ?? 'venue_${DateTime.now().millisecondsSinceEpoch}';
      final newUrls = await StorageService.uploadVenueImages(
        id,
        _pendingImages,
      );

      final venue = Venue(
        id: id,
        ownerId: widget.ownerId,
        name: _nameController.text,
        location: _locationController.text,
        city: _city,
        latitude: _lat,
        longitude: _lng,
        type: _selectedType,
        rating: widget.venue?.rating ?? 4.0,
        description: _descController.text,
        pricePerHour: double.parse(_priceController.text),
        images: [..._existingImages, ...newUrls],
        sportsTypes: _selectedSports,
        commissionRate: widget.venue?.commissionRate ?? 5,
        isSuspended: widget.venue?.isSuspended ?? false,
        openTimeHour: _openTime.hour,
        openTimeMinute: _openTime.minute,
        closeTimeHour: _closeTime.hour,
        closeTimeMinute: _closeTime.minute,
        morningPeakStartHour: _morningPeakStart.hour,
        morningPeakStartMinute: _morningPeakStart.minute,
        morningPeakEndHour: _morningPeakEnd.hour,
        morningPeakEndMinute: _morningPeakEnd.minute,
        eveningPeakStartHour: _eveningPeakStart.hour,
        eveningPeakStartMinute: _eveningPeakStart.minute,
        eveningPeakEndHour: _eveningPeakEnd.hour,
        eveningPeakEndMinute: _eveningPeakEnd.minute,
        peakMultiplier: _peakMultiplier,
        generalInstructions: _instrController.text,
        cancellationPolicy: _cancelController.text,
        rules: _rules,
      );

      await ref.read(venueRepositoryProvider).saveVenue(venue);
      ref.invalidate(ownerVenueProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
