import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final Venue venue;
  final List<Slot> slots;
  final String lockedByUserId;

  const CheckoutScreen({
    super.key,
    required this.venue,
    required this.slots,
    required this.lockedByUserId,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _promoController = TextEditingController();
  late final Razorpay _razorpay;

  double _discount = 0.0;
  bool _isProcessing = false;
  String? _appliedCouponCode;

  // Filled once createOrder succeeds, needed for verifyAndBook
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    debugPrint('[CheckoutScreen] initState: Initializing Razorpay');
    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
      debugPrint('[CheckoutScreen] initState: Razorpay initialized');
    } catch (e) {
      debugPrint(
        '[CheckoutScreen] initState: Razorpay initialization failed: $e',
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _promoController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  double get _subtotal => widget.slots.fold(0.0, (sum, s) => sum + s.price);

  double get _total => (_subtotal - _discount).clamp(0.0, double.infinity);

  // ── Coupon ───────────────────────────────────────────────────────────────

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final coupon = await ref
        .read(venueRepositoryProvider)
        .getCouponByCode(code);

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
      _discount = coupon.discountType == DiscountType.percentage
          ? _subtotal * (coupon.discountValue / 100)
          : coupon.discountValue;
      _appliedCouponCode = code;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon $code applied!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ── Razorpay flow ────────────────────────────────────────────────────────

  /// Step 1: Verify locks still valid → create server-side Razorpay order.
  Future<void> _startPayment() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _isProcessing = true);

    // 1a. Verify locks are still held by this user (haven't expired)
    final locksValid = await ref
        .read(bookingRepositoryProvider)
        .verifyLocks(widget.slots, widget.lockedByUserId);

    if (!locksValid) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your slot hold expired (10 min limit). Please select slots again.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      context.go('/venue/${widget.venue.id}');
      return;
    }

    // 1b. Call createOrder Cloud Function
    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('createOrder').call({
        'slotIds': widget.slots.map((s) => s.id).toList(),
        'venueId': widget.venue.id,
        'playerId': user.id,
        if (_appliedCouponCode != null) 'couponCode': _appliedCouponCode,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      _pendingOrderId = data['orderId'] as String;

      // cloud_functions can wrap large ints as fixnum.Int64 on some platforms.
      // Always parse via toString() to get a plain Dart int for the Razorpay SDK.
      final amount = int.parse(data['amount'].toString());

      // 1c. Open Razorpay SDK
      _razorpay.open({
        'key': data['keyId'],
        'order_id': _pendingOrderId,
        'amount': amount,
        'currency': data['currency'].toString(),
        'name': 'Namma Turfy',
        'description': 'Booking at ${widget.venue.name}',
        'prefill': {
          'email': user.email,
          'contact': user.phoneNumber ?? '',
          'name': user.name,
        },
        'theme': {'color': '#35CA67'},
      });
    } catch (e) {
      debugPrint('[CheckoutScreen] createOrder error: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);

      String errorMsg = 'Could not create payment order. Please try again.';
      if (e is FirebaseFunctionsException) {
        errorMsg = e.message ?? errorMsg;
      }
      _showError(errorMsg);
    }
  }

  /// Step 2: Payment succeeded — call verifyAndBook Cloud Function.
  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    final user = ref.read(currentUserProvider);
    if (user == null || _pendingOrderId == null) return;

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyAndBook')
          .call({
            'razorpayOrderId': _pendingOrderId,
            'razorpayPaymentId': response.paymentId,
            'razorpaySignature': response.signature,
            'playerId': user.id,
            'venueId': widget.venue.id,
            'zoneId': widget.slots.first.zoneId,
            'slotIds': widget.slots.map((s) => s.id).toList(),
            if (_appliedCouponCode != null) 'couponCode': _appliedCouponCode,
          });

      final data = Map<String, dynamic>.from(result.data as Map);
      final bookingId = data['bookingId'] as String;

      if (!mounted) return;
      context.go('/receipt/$bookingId');
    } catch (e) {
      debugPrint('[CheckoutScreen] verifyAndBook error: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);

      String errorMsg =
          'Payment received but booking failed. Contact support with payment ID: ${response.paymentId}';
      if (e is FirebaseFunctionsException) {
        errorMsg = '${e.message} (Payment ID: ${response.paymentId})';
      }
      _showError(errorMsg);
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showError('Payment failed: ${response.message ?? "Unknown error"}');
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName}'),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final commission = double.parse(
      (_total * widget.venue.commissionRate / 100).toStringAsFixed(2),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Booking Summary ──────────────────────────────────────────
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
                      value: '₹${_subtotal.toStringAsFixed(0)}',
                    ),
                    if (_discount > 0)
                      _SummaryRow(
                        label: 'Coupon ($_appliedCouponCode)',
                        value: '- ₹${_discount.toStringAsFixed(0)}',
                        color: Colors.green,
                      ),
                    _SummaryRow(
                      label: 'Total Payable',
                      value: '₹${_total.toStringAsFixed(0)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),

            // ── Slot hold timer notice ───────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_clock, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Slots are held for 10 minutes. Complete payment before time runs out.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

            // ── Promo Code ───────────────────────────────────────────────
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
                    enabled: _appliedCouponCode == null,
                    decoration: InputDecoration(
                      hintText: 'Enter code (e.g. SAVE20)',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      suffixIcon: _appliedCouponCode != null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _appliedCouponCode != null ? null : _applyPromo,
                  child: const Text('Apply'),
                ),
              ],
            ),

            // ── Commission disclosure (transparent) ──────────────────────
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Platform fee (${widget.venue.commissionRate}%)',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    '₹${commission.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),

      // ── Pay Button ───────────────────────────────────────────────────────
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
            onPressed: _isProcessing ? null : _startPayment,
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
                    'Pay ₹${_total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
