import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:namma_turfy/core/services/razorpay_service_impl.dart';

/// Handles the Razorpay redirect callback on mobile web.
///
/// After a mobile-web payment, Razorpay redirects to:
///   /payment-callback?razorpay_payment_id=xxx&razorpay_order_id=yyy&razorpay_signature=zzz
///
/// GoRouter passes the query params directly as constructor arguments.
/// Booking metadata is retrieved from sessionStorage (stored before the redirect).
class PaymentCallbackScreen extends ConsumerStatefulWidget {
  final String? paymentId;
  final String? orderId;
  final String? signature;

  const PaymentCallbackScreen({
    super.key,
    this.paymentId,
    this.orderId,
    this.signature,
  });

  @override
  ConsumerState<PaymentCallbackScreen> createState() =>
      _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends ConsumerState<PaymentCallbackScreen> {
  String _status = 'Confirming your payment…';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  Future<void> _handleCallback() async {
    final paymentId = widget.paymentId;
    final orderId = widget.orderId;
    final signature = widget.signature;

    debugPrint(
      '[Callback] Handling callback: paymentId=$paymentId, orderId=$orderId',
    );

    if (paymentId == null || orderId == null || signature == null) {
      debugPrint('[Callback] Error: missing params from Razorpay redirect');
      setState(() {
        _failed = true;
        _status = 'Payment response missing. Please contact support.';
      });
      return;
    }

    // Retrieve booking metadata stored in sessionStorage before the redirect.
    Map<String, dynamic>? meta;
    try {
      debugPrint('[Callback] Retrieving stored meta for order $orderId');
      meta = RazorpayServiceImpl.getStoredBookingData(orderId);
    } catch (e) {
      debugPrint('[Callback] getStoredBookingData failed: $e');
    }

    if (meta == null) {
      debugPrint('[Callback] Error: no meta found in sessionStorage');
      setState(() {
        _failed = true;
        _status =
            'Session data missing. Payment ID: $paymentId\nPlease contact support.';
      });
      return;
    }

    // ── Wait for Firebase Auth to restore session ─────────────────────────
    // After a Razorpay mobile-web redirect the page does a full reload.
    // Firebase Auth restores the session from IndexedDB asynchronously, so
    // we must wait for a non-null user before calling the authenticated
    // Cloud Function — otherwise the callable fires unauthenticated and the
    // server rejects it with "unauthenticated" (no booking is created, no log).
    try {
      setState(() => _status = 'Restoring session…');
      await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception(
            'Session restore timed out. Please log in again and check My Bookings.',
          );
        },
      );
      debugPrint('[Callback] Auth session restored');
    } catch (e) {
      debugPrint('[Callback] Auth restore failed: $e');
      setState(() {
        _failed = true;
        _status = e.toString();
      });
      return;
    }

    try {
      setState(() => _status = 'Confirming your booking…');
      debugPrint('[Callback] Calling verifyAndBook');
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyAndBook')
          .call({
            'razorpayOrderId': orderId,
            'razorpayPaymentId': paymentId,
            'razorpaySignature': signature,
            'playerId': meta['playerId'],
            'venueId': meta['venueId'],
            'zoneId': meta['zoneId'],
            'slotIds': meta['slotIds'],
            if (meta['couponCode'] != null) 'couponCode': meta['couponCode'],
          });

      final data = Map<String, dynamic>.from(result.data as Map);
      final bookingId = data['bookingId'] as String;
      debugPrint('[Callback] verifyAndBook success: bookingId=$bookingId');

      if (mounted) context.go('/my-bookings');
    } catch (e) {
      debugPrint('[Callback] verifyAndBook failed: $e');
      final msg = e is FirebaseFunctionsException
          ? e.message ?? e.toString()
          : e.toString();
      setState(() {
        _failed = true;
        _status = '$msg\n\nPayment ID: $paymentId';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Booking Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/my-bookings'),
                      icon: const Icon(Icons.history),
                      label: const Text('Check My Bookings'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Go Home'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF35CA67)),
                    const SizedBox(height: 24),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
