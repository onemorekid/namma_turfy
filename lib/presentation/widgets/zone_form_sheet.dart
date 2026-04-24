import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:namma_turfy/core/services/storage_service.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:namma_turfy/presentation/widgets/app_network_image.dart';
import 'dart:typed_data';

class ZoneFormSheet extends ConsumerStatefulWidget {
  final Venue venue;
  final Zone? zone;

  const ZoneFormSheet({super.key, required this.venue, this.zone});

  @override
  ConsumerState<ZoneFormSheet> createState() => _ZoneFormSheetState();
}

class _ZoneFormSheetState extends ConsumerState<ZoneFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  late String _selectedSport;

  List<String> _existingImages = [];
  final List<XFile> _pendingImages = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final z = widget.zone;
    _nameController = TextEditingController(text: z?.name ?? '');
    _capacityController = TextEditingController(
      text: z?.capacity?.toString() ?? '',
    );
    _selectedSport =
        z?.type ??
        (widget.venue.sportsTypes.isNotEmpty
            ? widget.venue.sportsTypes.first
            : 'Football');
    _existingImages = List.from(z?.images ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    widget.zone == null ? 'Add Zone' : 'Edit Zone',
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
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Zone Name* (e.g. Pitch A)',
                      ),
                      maxLength: 60,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSport,
                      items: widget.venue.sportsTypes
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSport = v!),
                      decoration: const InputDecoration(
                        labelText: 'Sport Type*',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _capacityController,
                      decoration: const InputDecoration(
                        labelText: 'Capacity (optional)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Photos (At least 1 required)',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.zone == null ? 'Add Zone' : 'Save Changes'),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImages.isEmpty && _pendingImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one photo')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final id =
          widget.zone?.id ?? 'zone_${DateTime.now().millisecondsSinceEpoch}';
      final newUrls = await StorageService.uploadZoneImages(id, _pendingImages);
      final allUrls = [..._existingImages, ...newUrls];

      final zone = Zone(
        id: id,
        venueId: widget.venue.id,
        name: _nameController.text,
        type: _selectedSport,
        images: allUrls,
        capacity: int.tryParse(_capacityController.text),
      );

      await ref.read(venueRepositoryProvider).saveZone(zone);

      // Zone photo bug fix: write first image to venue.images if needed
      if (allUrls.isNotEmpty) {
        final firstImageUrl = allUrls.first;
        if (!widget.venue.images.contains(firstImageUrl)) {
          final updatedVenue = widget.venue.copyWith(
            images: [...widget.venue.images, firstImageUrl],
          );
          await ref.read(venueRepositoryProvider).saveVenue(updatedVenue);
          ref.invalidate(ownerVenueProvider);
        }
      }

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
