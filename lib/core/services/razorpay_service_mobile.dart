import 'package:flutter/foundation.dart';
import 'razorpay_service.dart';

// We must NOT import razorpay_flutter on web, even conditionally in some cases,
// because dart2wasm may still try to compile it.
import 'razorpay_service_mobile_stub.dart'
    if (dart.library.io) 'package:razorpay_flutter/razorpay_flutter.dart';

/// Android / iOS implementation — delegates to the razorpay_flutter plugin.
class RazorpayServiceImpl implements RazorpayService {
  dynamic _razorpay;

  RazorpayServiceImpl() {
    if (!kIsWeb) {
      try {
        // ignore: undefined_class
        _razorpay = Razorpay();
      } catch (e) {
        debugPrint('[RazorpayMobile] Failed to init: $e');
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

    }
  }

  /// Stub for the static method needed by PaymentCallbackScreen
  static Map<String, dynamic>? getStoredBookingData(String orderId) => null;
}
