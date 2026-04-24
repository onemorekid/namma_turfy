import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';

class SlotGenerationSheet extends ConsumerStatefulWidget {
  final Venue venue;
  final String zoneId;

  const SlotGenerationSheet({
    super.key,
    required this.venue,
    required this.zoneId,
  });

  @override
  ConsumerState<SlotGenerationSheet> createState() =>
      _SlotGenerationSheetState();
}

class _SlotGenerationSheetState extends ConsumerState<SlotGenerationSheet> {
  int _currentStep = 1;

  // Step 1 State
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  int _duration = 60;
  double _basePrice = 500;

  // Step 2 State
  List<Slot> _previewSlots = [];
  Set<String> _conflicts = {};
  bool _isLoadingPreview = false;

  @override
  void initState() {
    super.initState();
    _basePrice = widget.venue.pricePerHour;
    if (widget.venue.openTimeHour != null) {
      _startTime = TimeOfDay(
        hour: widget.venue.openTimeHour!,
        minute: widget.venue.openTimeMinute ?? 0,
      );
    }
    if (widget.venue.closeTimeHour != null) {
      _endTime = TimeOfDay(
        hour: widget.venue.closeTimeHour!,
        minute: widget.venue.closeTimeMinute ?? 0,
      );
    }
  }

  bool _isPeak(DateTime start) {
    final v = widget.venue;
    final startMinutes = start.hour * 60 + start.minute;

    final morningStart = v.morningPeakStartHour * 60 + v.morningPeakStartMinute;
    final morningEnd = v.morningPeakEndHour * 60 + v.morningPeakEndMinute;
    if (startMinutes >= morningStart && startMinutes < morningEnd) return true;

    final eveningStart = v.eveningPeakStartHour * 60 + v.eveningPeakStartMinute;
    final eveningEnd = v.eveningPeakEndHour * 60 + v.eveningPeakEndMinute;
    if (startMinutes >= eveningStart && startMinutes < eveningEnd) return true;

    return false;
  }

  Future<void> _generatePreview() async {
    setState(() => _isLoadingPreview = true);
    final slots = <Slot>[];
    final now = DateTime.now();

    // Calculate slots
    for (int i = 0; i <= _endDate.difference(_startDate).inDays; i++) {
      final date = _startDate.add(Duration(days: i));
      DateTime current = DateTime(
        date.year,
        date.month,
        date.day,
        _startTime.hour,
        _startTime.minute,
      );
      final dayEnd = DateTime(
        date.year,
        date.month,
        date.day,
        _endTime.hour,
        _endTime.minute,
      );

      while (current.isBefore(dayEnd)) {
        final slotEnd = current.add(Duration(minutes: _duration));
        if (current.isAfter(now)) {
          final peak = _isPeak(current);
          slots.add(
            Slot(
              id: 'slot_${widget.zoneId}_${current.millisecondsSinceEpoch}',
              zoneId: widget.zoneId,
              startTime: current,
              endTime: slotEnd,
              price: peak
                  ? _basePrice * widget.venue.peakMultiplier
                  : _basePrice,
              status: SlotStatus.available,
            ),
          );
        }
        current = slotEnd;
      }
    }

    // Conflict detection
    try {
      final existing = await ref
          .read(venueRepositoryProvider)
          .getSlotsInRange(
            widget.zoneId,
            _startDate,
            _endDate.add(const Duration(days: 1)),
          );
      final existingStarts = existing
          .map((s) => s.startTime.millisecondsSinceEpoch)
          .toSet();
      _conflicts = slots
          .where(
            (s) => existingStarts.contains(s.startTime.millisecondsSinceEpoch),
          )
          .map((s) => s.id)
          .toSet();
    } catch (e) {
      // Handle error
    }

    setState(() {
      _previewSlots = slots;
      _isLoadingPreview = false;
      _currentStep = 2;
    });
  }

  Future<void> _saveSlots() async {
    setState(() => _isLoadingPreview = true);
    try {
      final finalBatch = _previewSlots
          .where((s) => !_conflicts.contains(s.id))
          .toList();
      await ref.read(venueRepositoryProvider).bulkSaveSlots(finalBatch);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoadingPreview = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
                    'Interactive Slot Builder',
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
              child: _currentStep == 1
                  ? _buildStep1()
                  : _buildStep2(scrollController),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Text(
          'Step 1: Configure Generation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          title: const Text('Date Range'),
          subtitle: Text(
            '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
            );
            if (picked != null) {
              setState(() {
                _startDate = picked.start;
                _endDate = picked.end;
              });
            }
          },
        ),
        Row(
          children: [
            Expanded(
              child: _timeField(
                'Start Time',
                _startTime,
                (t) => setState(() => _startTime = t),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _timeField(
                'End Time',
                _endTime,
                (t) => setState(() => _endTime = t),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Slot Duration'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [30, 60, 90, 120]
              .map(
                (d) => ChoiceChip(
                  label: Text('$d min'),
                  selected: _duration == d,
                  onSelected: (val) {
                    if (val) setState(() => _duration = d);
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          decoration: const InputDecoration(labelText: 'Base Price (₹)'),
          keyboardType: TextInputType.number,
          onChanged: (v) => _basePrice = double.tryParse(v) ?? _basePrice,
          controller: TextEditingController(
            text: _basePrice.toStringAsFixed(0),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Peak multiplier: ${widget.venue.peakMultiplier}x (Auto-applied)',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.peakTime),
        ),
      ],
    );
  }

  Widget _buildStep2(ScrollController scrollController) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Step 2: Preview Grid',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${_previewSlots.length} slots generated. ${_conflicts.length} conflicts found.',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: _previewSlots.length,
            itemBuilder: (context, index) {
              final slot = _previewSlots[index];
              final hasConflict = _conflicts.contains(slot.id);
              final peak = _isPeak(slot.startTime);

              return Container(
                color: peak ? AppColors.peakTimeBg : null,
                child: ListTile(
                  leading: peak
                      ? const Icon(
                          Icons.flash_on,
                          color: AppColors.peakTime,
                          size: 16,
                        )
                      : null,
                  title: Text(
                    '${DateFormat('hh:mm a').format(slot.startTime)} - ${DateFormat('hh:mm a').format(slot.endTime!)}',
                  ),
                  subtitle: Text(
                    DateFormat('EEE, dd MMM').format(slot.startTime),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasConflict)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text(
                            '⚠️ Exists',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixText: '₹',
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: slot.price.toStringAsFixed(0),
                          ),
                          onSubmitted: (v) {
                            setState(() {
                              _previewSlots[index] = slot.copyWith(
                                price: double.tryParse(v) ?? slot.price,
                              );
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _previewSlots.removeAt(index)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (_currentStep == 2) ...[
            TextButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('Back'),
            ),
            const Spacer(),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoadingPreview
                  ? null
                  : (_currentStep == 1 ? _generatePreview : _saveSlots),
              child: _isLoadingPreview
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _currentStep == 1
                          ? 'Preview Slots'
                          : 'Confirm & Generate',
                    ),
            ),
          ),
        ],
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
        if (picked != null) onSelected(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(time.format(context)),
      ),
    );
  }
}
