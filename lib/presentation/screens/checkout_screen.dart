import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/core/services/razorpay_service.dart';
import 'package:namma_turfy/core/services/razorpay_service_impl.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';

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
  final RazorpayService _razorpay = RazorpayServiceImpl();

  double _discount = 0.0;
  bool _isProcessing = false;
  String? _appliedCouponCode;

  // Set after createOrder succeeds; used when web needs a second tap.
  String? _pendingOrderId;
  Map<String, dynamic>? _pendingOptions;

  @override
  void initState() {
    super.initState();
    _razorpay.setup(
      onSuccess: _onPaymentSuccess,
      onError: _onPaymentError,
      onExternalWallet: _onExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _promoController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  double get _subtotal => widget.slots.fold(0.0, (s, slot) => s + slot.price);
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
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ── Razorpay flow ─────────────────────────────────────────────────────────

  /// Step 1 — verify slot locks → create server-side Razorpay order.
  /// On mobile: opens checkout immediately.
  /// On web: stores options and waits for the user to tap "Open Payment".
  Future<void> _startPayment() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _isProcessing = true);

    // Verify locks haven't expired.
    final locksValid = await ref
        .read(bookingRepositoryProvider)
        .verifyLocks(widget.slots, widget.lockedByUserId);

    if (!locksValid) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Slot hold expired (10 min). Please select slots again.',
          ),
          backgroundColor: AppColors.peakTime,
        ),
      );
      context.go('/venue/${widget.venue.id}');
      return;
    }

    try {
      debugPrint('[Checkout] Calling createOrder Cloud Function...');
      final result = await FirebaseFunctions.instance
          .httpsCallable('createOrder')
          .call({
            'slotIds': widget.slots.map((s) => s.id).toList(),
            'venueId': widget.venue.id,
            'playerId': user.id,
            if (_appliedCouponCode != null) 'couponCode': _appliedCouponCode,
          });

      final data = Map<String, dynamic>.from(result.data as Map);
      _pendingOrderId = data['orderId'] as String;
      debugPrint('[Checkout] createOrder success: $_pendingOrderId');

      // Validate server-side discount matches client expectation
      if (_appliedCouponCode != null) {
        final serverDiscount = (data['discountApplied'] as num).toDouble();
        final clientDiscountPaise = (_discount * 100).round();
        if ((serverDiscount - clientDiscountPaise).abs() > 1) {
          debugPrint(
            '[Checkout] Discount mismatch: server=$serverDiscount, client=$clientDiscountPaise',
          );
          if (!mounted) return;
          setState(() => _isProcessing = false);
          _showError(
            'Coupon could not be applied server-side. Please try again.',
          );
          return;
        }
      }

      // Parse amount safely — mobile web returns doubles (e.g. 50000.0),
      // desktop web may return int or fixnum.Int64. Cast via num to handle all.
      final amount = (data['amount'] as num).toInt();

      final options = <String, dynamic>{
        'key': data['keyId'].toString(),
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
        // Stored in sessionStorage by the web service before mobile redirect.
        // Stripped before passing to Razorpay SDK.
        '_bookingMeta': {
          'venueId': widget.venue.id,
          'zoneId': widget.slots.first.zoneId,
          'slotIds': widget.slots.map((s) => s.id).toList(),
          'playerId': user.id,
          if (_appliedCouponCode != null) 'couponCode': _appliedCouponCode,
        },
      };

      if (kIsWeb) {
        debugPrint(
          '[Checkout] Web detected, setting _pendingOptions and updating UI',
        );
        // Web (Desktop & Mobile): store options and show "Open Payment" button.
        // Browsers block the Razorpay modal/redirect if it's not triggered
        // by a direct user gesture (tap).
        setState(() {
          _pendingOptions = options;
          _isProcessing = false;
        });
      } else {
        debugPrint('[Checkout] Native detected, opening Razorpay immediately');
        // Native Mobile: open the SDK immediately.
        setState(() => _isProcessing = false);
        _razorpay.open(options);
      }
    } catch (e) {
      debugPrint('[Checkout] Error in _startPayment: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      String msg = 'Could not create payment order. Please try again.';
      if (e is FirebaseFunctionsException) msg = e.message ?? msg;
      _showError(msg);
    }
  }

  /// Step 1b — web only: open the Razorpay modal from a direct user tap.
  void _openWebPayment() {
    debugPrint(
      '[Checkout] _openWebPayment called, orderReady=${_pendingOptions != null}',
    );
    if (_pendingOptions == null) {
      debugPrint(
        '[Checkout] Error: _pendingOptions is null in _openWebPayment',
      );
      return;
    }
    try {
      debugPrint(
        '[Checkout] Invoking _razorpay.open with order ${_pendingOptions?['order_id']}',
      );
      _razorpay.open(_pendingOptions!);
    } catch (e) {
      debugPrint('[Checkout] Exception in _razorpay.open: $e');
      _showError('Failed to open payment gateway: $e');
    }
  }

  /// Step 2 — payment succeeded → call verifyAndBook.
  void _onPaymentSuccess(
    String paymentId,
    String orderId,
    String signature,
  ) async {
    debugPrint(
      '[Checkout] _onPaymentSuccess: paymentId=$paymentId, orderId=$orderId',
    );
    final user = ref.read(currentUserProvider);
    final actualOrderId = (orderId.isNotEmpty) ? orderId : _pendingOrderId;

    if (user == null) {
      debugPrint('[Checkout] Error: user is null in _onPaymentSuccess');
      return;
    }
    if (actualOrderId == null) {
      debugPrint('[Checkout] Error: orderId is null in _onPaymentSuccess');
      _showError('Critical error: Payment successful but order ID missing.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      debugPrint('[Checkout] Calling verifyAndBook for order $actualOrderId');
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyAndBook')
          .call({
            'razorpayOrderId': actualOrderId,
            'razorpayPaymentId': paymentId,
            'razorpaySignature': signature,
            'playerId': user.id,
            'venueId': widget.venue.id,
            'zoneId': widget.slots.first.zoneId,
            'slotIds': widget.slots.map((s) => s.id).toList(),
            if (_appliedCouponCode != null) 'couponCode': _appliedCouponCode,
          });

      final data = Map<String, dynamic>.from(result.data as Map);
      final bookingId = data['bookingId'] as String;
      debugPrint('[Checkout] verifyAndBook success: bookingId=$bookingId');

      if (!mounted) return;
      context.go('/my-bookings');
    } catch (e) {
      debugPrint('[Checkout] verifyAndBook failed: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      String msg =
          'Payment received but booking failed. Contact support with payment ID: $paymentId';
      if (e is FirebaseFunctionsException) {
        msg = '${e.message} (Payment ID: $paymentId)';
      }
      _showError(msg);
    }
  }

  void _onPaymentError(int? code, String? message) {
    debugPrint('[Checkout] _onPaymentError: code=$code, message=$message');
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _pendingOptions = null;
    });
    _showError('Payment failed: ${message ?? "Unknown error"}');

    // Log to Firestore for ops visibility (fire-and-forget).
    final user = ref.read(currentUserProvider);
    FirebaseFirestore.instance
        .collection('payment_attempts')
        .add({
          'razorpayOrderId': _pendingOrderId,
          'playerId': user?.id,
          'venueId': widget.venue.id,
          'status': 'failed',
          'errorCode': code,
          'errorDescription': message,
          'source': 'client_sdk',
          'createdAt': FieldValue.serverTimestamp(),
        })
        .catchError((e) => e); // satisfy Future<DocumentReference> return type
  }

  void _onExternalWallet(String? walletName) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: $walletName')),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final orderReady = _pendingOptions != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Booking Summary ────────────────────────────────────────────
            Text('Booking Summary', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: const Border.fromBorderSide(
                  BorderSide(color: AppColors.outline),
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _SummaryRow(label: 'Venue', value: widget.venue.name),
                  _SummaryRow(
                    label: 'Date',
                    value: DateFormat(
                      'MMM dd, yyyy',
                    ).format(widget.slots.first.startTime),
                  ),
                  _SummaryRow(label: 'Slots', value: '${widget.slots.length}'),
                  const Divider(height: AppSpacing.md),
                  ...widget.slots.map(
                    (s) => _SummaryRow(
                      label: DateFormat('hh:mm a').format(s.startTime),
                      value: '₹${s.price.toStringAsFixed(0)}',
                      isSmall: true,
                    ),
                  ),
                  const Divider(height: AppSpacing.md),
                  _SummaryRow(
                    label: 'Subtotal',
                    value: '₹${_subtotal.toStringAsFixed(0)}',
                  ),
                  if (_discount > 0)
                    _SummaryRow(
                      label: 'Coupon ($_appliedCouponCode)',
                      value: '- ₹${_discount.toStringAsFixed(0)}',
                      color: AppColors.primary,
                    ),
                  _SummaryRow(
                    label: 'Total Payable',
                    value: '₹${_total.toStringAsFixed(0)}',
                    isBold: true,
                  ),
                ],
              ),
            ),

            // ── Slot hold notice ───────────────────────────────────────────
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.offerBg,
                borderRadius: BorderRadius.circular(10),
                border: const Border.fromBorderSide(
                  BorderSide(color: AppColors.offer),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_clock,
                    color: AppColors.offer,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Slots held for 10 minutes. Complete payment soon.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.offer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Promo Code ─────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.lg),
            Text('Promo Code', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    enabled: _appliedCouponCode == null,
                    decoration: InputDecoration(
                      hintText: 'Enter code (e.g. SAVE20)',
                      suffixIcon: _appliedCouponCode != null
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _appliedCouponCode != null ? null : _applyPromo,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),

      // ── Bottom CTA ─────────────────────────────────────────────────────────
      bottomNavigationBar: Container(
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
          child: ElevatedButton(
            onPressed: _isProcessing
                ? null
                : (orderReady ? _openWebPayment : _startPayment),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: orderReady
                  ? const Color(0xFF1E88E5)
                  : AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                    orderReady
                        ? 'Open Payment Gateway'
                        : 'Proceed to Payment  ₹${_total.toStringAsFixed(0)}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widget ─────────────────────────────────────────────────────────────

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
    final baseStyle = isSmall
        ? AppTextStyles.bodySmall
        : AppTextStyles.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: baseStyle.copyWith(color: AppColors.onSurfaceVar)),
          Text(
            value,
            style: isBold
                ? AppTextStyles.titleMedium.copyWith(
                    color: color ?? AppColors.onSurface,
                  )
                : baseStyle.copyWith(
                    color: color ?? AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ],
      ),
    );
  }
}
