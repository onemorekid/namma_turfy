import 'package:flutter/foundation.dart';
import 'razorpay_service.dart';

// Import stub for web, and native only for IO.
import 'razorpay_service_mobile_stub.dart'
    if (dart.library.io) 'package:razorpay_flutter/razorpay_flutter.dart';

/// Android / iOS implementation — delegates to the razorpay_flutter plugin.
class RazorpayServiceMobile implements RazorpayService {
  dynamic _razorpay;

  RazorpayServiceMobile() {
    if (!kIsWeb) {
      try {
        // ignore: undefined_class
        _razorpay = Razorpay();
      } catch (e) {
        debugPrint('[RazorpayMobile] Failed to initialize native SDK: $e');
      }
    }
  }

  @override
  bool get requiresUserGesture => false;

  @override
  void setup({
    required OnPaymentSuccess onSuccess,
    required OnPaymentError onError,
    required OnExternalWallet onExternalWallet,
  }) {
    if (kIsWeb || _razorpay == null) return;

    try {
      // ignore: undefined_identifier
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (dynamic r) {
        onSuccess(r.paymentId ?? '', r.orderId ?? '', r.signature ?? '');
      });
      // ignore: undefined_identifier
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (dynamic r) {
        onError(r.code, r.message);
      });
      // ignore: undefined_identifier
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (dynamic r) {
        onExternalWallet(r.walletName);
      });
    } catch (e) {
      debugPrint('[RazorpayMobile] Error setting up listeners: $e');
    }
  }

  @override
  void open(Map<String, dynamic> options) {
    if (!kIsWeb && _razorpay != null) {
      _razorpay.open(options);
    }
  }

  @override
  void clear() {
    if (!kIsWeb && _razorpay != null) {
      _razorpay.clear();
    }
  }

  /// Stub for mobile
  static Map<String, dynamic>? getStoredBookingData(String orderId) => null;
}
