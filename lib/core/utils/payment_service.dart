import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:developer' as developer;

class PaymentService {
  final Razorpay _razorpay = Razorpay();
  final void Function(PaymentSuccessResponse)? onSuccess;
  final void Function(PaymentFailureResponse)? onFailure;
  final void Function(ExternalWalletResponse)? onExternalWallet;

  PaymentService({this.onSuccess, this.onFailure, this.onExternalWallet}) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    developer.log('Payment Success: ${response.paymentId}');
    onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    developer.log('Payment Error: ${response.code} - ${response.message}');
    onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    developer.log('External Wallet: ${response.walletName}');
    onExternalWallet?.call(response);
  }

  void openCheckout({
    required String key,
    required double amount,
    required String name,
    required String description,
    required String email,
    required String contact,
  }) {
    var options = {
      'key': key,
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': name,
      'description': description,
      'prefill': {'contact': contact, 'email': email},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      developer.log('Error in opening Razorpay: $e');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}

final paymentServiceProvider =
    Provider.family<
      PaymentService,
      ({
        void Function(PaymentSuccessResponse)? onSuccess,
        void Function(PaymentFailureResponse)? onFailure,
        void Function(ExternalWalletResponse)? onExternalWallet,
      })
    >((ref, callbacks) {
      final service = PaymentService(
        onSuccess: callbacks.onSuccess,
        onFailure: callbacks.onFailure,
        onExternalWallet: callbacks.onExternalWallet,
      );
      ref.onDispose(() => service.dispose());
      return service;
    });
