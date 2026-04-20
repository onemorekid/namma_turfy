import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/domain/entities/slot.dart';

enum SlotRowState { available, peak, booked, selected }

/// Row-style slot tile used on the venue details and checkout screens.
///
///  Available  → white bg, green "Available" badge, green ✓
///  Peak Time  → peakTimeBg, orange "Peak Time" badge, red ✗, price in peakTime
///  Booked     → surfaceVariant bg, grey "Booked" badge, greyed-out text
///  Selected   → primaryLight bg, 2px primary border
class SlotRowWidget extends StatelessWidget {
  final Slot slot;
  final bool isSelected;
  final bool isPeak;
  final VoidCallback? onTap;

  const SlotRowWidget({
    super.key,
    required this.slot,
    this.isSelected = false,
    this.isPeak = false,
    this.onTap,
  });

  SlotRowState get _state {
    final isPast = slot.startTime.isBefore(DateTime.now());
    if (slot.status == SlotStatus.booked || isPast) return SlotRowState.booked;
    if (isSelected) return SlotRowState.selected;
    if (isPeak) return SlotRowState.peak;
    return SlotRowState.available;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final isInteractive = state == SlotRowState.available ||
        state == SlotRowState.peak ||
        state == SlotRowState.selected;

    return GestureDetector(
      onTap: isInteractive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeIn,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _bgColor(state),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: state == SlotRowState.selected
                ? AppColors.primary
                : AppColors.outline,
            width: state == SlotRowState.selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // ── Time + price ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.endTime != null
                        ? '${DateFormat('hh:mm a').format(slot.startTime)} – '
                          '${DateFormat('hh:mm a').format(slot.endTime!)}'
                        : DateFormat('hh:mm a').format(slot.startTime),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: state == SlotRowState.booked
                          ? AppColors.outlineVariant
                          : AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${slot.price.toStringAsFixed(0)}',
                    style: state == SlotRowState.peak
                        ? AppTextStyles.pricePeak
                        : AppTextStyles.priceRegular.copyWith(
                            color: state == SlotRowState.booked
                                ? AppColors.outlineVariant
                                : null,
                          ),
                  ),
                ],
              ),
            ),

            // ── Badge + icon ────────────────────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Badge(state: state),
                const SizedBox(width: 8),
                _StateIcon(state: state),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _bgColor(SlotRowState state) {
    switch (state) {
      case SlotRowState.available:
        return AppColors.surface;
      case SlotRowState.peak:
        return AppColors.peakTimeBg;
      case SlotRowState.booked:
        return AppColors.surfaceVariant;
      case SlotRowState.selected:
        return AppColors.primaryLight;
    }
  }
}

// ── Internal badge pill ────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final SlotRowState state;
  const _Badge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, bg) = switch (state) {
      SlotRowState.available => ('Available', AppColors.primary),
      SlotRowState.peak      => ('Peak Time', AppColors.peakTime),
      SlotRowState.booked    => ('Booked',    AppColors.outlineVariant),
      SlotRowState.selected  => ('Selected',  AppColors.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
      ),
    );
  }
}

// ── Internal state icon ────────────────────────────────────────────────────────

class _StateIcon extends StatelessWidget {
  final SlotRowState state;
  const _StateIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      SlotRowState.available => (Icons.check_circle, AppColors.primary),
      SlotRowState.peak      => (Icons.cancel,       AppColors.error),
      SlotRowState.booked    => (Icons.cancel,        AppColors.outlineVariant),
      SlotRowState.selected  => (Icons.check_circle,  AppColors.primary),
    };
    return Icon(icon, size: 20, color: color);
  }
}
