import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/core/services/payment_service.dart';
import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final Venue venue;
  final List<Slot> slots;

  const CheckoutScreen({super.key, required this.venue, required this.slots});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.digital;
  final _promoController = TextEditingController();
  double _discount = 0.0;
  bool _isProcessing = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _applyPromo(double subtotal) async {
    if (_promoController.text.isEmpty) return;
    final coupon = await ref
        .read(venueRepositoryProvider)
        .getCouponByCode(_promoController.text.trim().toUpperCase());

    if (coupon == null) {
      _showError('Invalid coupon code');
      return;
    }
    if (coupon.validTo.isBefore(DateTime.now())) {
      _showError('Coupon has expired');
      return;
    }
    if (coupon.restrictedEmails != null &&
        coupon.restrictedEmails!.isNotEmpty) {
      final user = ref.read(currentUserProvider);
      if (user == null || !coupon.restrictedEmails!.contains(user.email)) {
        _showError('This coupon is not valid for your account');
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      if (coupon.discountType == DiscountType.percentage) {
        _discount = subtotal * (coupon.discountValue / 100);
      } else {
        _discount = coupon.discountValue;
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coupon applied!')));
  }

  Future<void> _confirmBooking(double total) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _isProcessing = true);

    // 1. Lock slots (concurrency guard)
    final locked = await ref
        .read(bookingRepositoryProvider)
        .lockSlots(widget.slots);
    if (!locked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('One or more slots just got booked. Please try again.'),
        ),
      );
      context.pop();
      return;
    }

    // 2. Process payment
    bool paymentSuccess = true;
    if (_paymentMethod == PaymentMethod.digital) {
      paymentSuccess = await ref
          .read(paymentServiceProvider)
          .processPayment(
            amount: total,
            name: user.name,
            email: user.email,
            description: 'Booking at ${widget.venue.name}',
          );
    }

    if (paymentSuccess) {
      final booking = await ref
          .read(bookingRepositoryProvider)
          .createBooking(
            playerId: user.id,
            venueId: widget.venue.id,
            zoneId: widget.slots.first.zoneId,
            slots: widget.slots,
            totalPrice: total,
            paymentMethod: _paymentMethod,
          );
      if (!mounted) return;
      context.go('/receipt/${booking.id}');
    } else {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.slots.fold(0.0, (sum, s) => sum + s.price);
    final total = (subtotal - _discount).clamp(0.0, double.infinity);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Summary',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Venue', value: widget.venue.name),
                    _SummaryRow(
                      label: 'Date',
                      value: DateFormat(
                        'MMM dd, yyyy',
                      ).format(widget.slots.first.startTime),
                    ),
                    _SummaryRow(
                      label: 'Slots',
                      value: '${widget.slots.length}',
                    ),
                    const Divider(),
                    ...widget.slots.map(
                      (s) => _SummaryRow(
                        label: DateFormat('hh:mm a').format(s.startTime),
                        value: '₹${s.price.toStringAsFixed(0)}',
                        isSmall: true,
                      ),
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Subtotal',
                      value: '₹${subtotal.toStringAsFixed(0)}',
                    ),
                    if (_discount > 0)
                      _SummaryRow(
                        label: 'Discount',
                        value: '- ₹${_discount.toStringAsFixed(0)}',
                        color: Colors.green,
                      ),
                    _SummaryRow(
                      label: 'Total Payable',
                      value: '₹${total.toStringAsFixed(0)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Promo Code',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Enter code (e.g. TURFY20)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _applyPromo(subtotal),
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _PaymentOption(
              label: 'Pay Online (Digital)',
              icon: Icons.payment,
              isSelected: _paymentMethod == PaymentMethod.digital,
              onTap: () =>
                  setState(() => _paymentMethod = PaymentMethod.digital),
            ),
            _PaymentOption(
              label: 'Pay at Venue (Cash)',
              icon: Icons.payments_outlined,
              isSelected: _paymentMethod == PaymentMethod.payAtVenue,
              onTap: () =>
                  setState(() => _paymentMethod = PaymentMethod.payAtVenue),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : () => _confirmBooking(total),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: const Color(0xFF35CA67),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _paymentMethod == PaymentMethod.digital
                        ? 'Pay ₹${total.toStringAsFixed(0)}'
                        : 'Confirm Booking (Pay ₹${total.toStringAsFixed(0)} at Venue)',
                  ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isSmall;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isSmall = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 12 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 12 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF35CA67) : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF35CA67) : Colors.grey,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF35CA67) : Colors.black,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF35CA67)),
          ],
        ),
      ),
    );
  }
}
