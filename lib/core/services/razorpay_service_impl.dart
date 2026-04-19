import 'package:flutter/foundation.dart';
import 'razorpay_service.dart';

// 1. Always import web implementation (it's safe as it uses js_interop which is available everywhere)
import 'razorpay_service_web.dart';

// 2. Conditionally import mobile implementation or stub
import 'razorpay_service_mobile_stub.dart'
    if (dart.library.io) 'razorpay_service_mobile.dart';

/// Platform-agnostic factory for RazorpayService.
class RazorpayServiceImpl implements RazorpayService {
  late final RazorpayService _delegate;

  RazorpayServiceImpl() {
    if (kIsWeb) {
      _delegate = RazorpayServiceWeb();
    } else {
      _delegate = RazorpayServiceMobile();
    }
  }

  @override
  bool get requiresUserGesture => _delegate.requiresUserGesture;

  @override
  void setup({
    required OnPaymentSuccess onSuccess,
    required OnPaymentError onError,
    required OnExternalWallet onExternalWallet,
  }) {
    _delegate.setup(
      onSuccess: onSuccess,
      onError: onError,
      onExternalWallet: onExternalWallet,
    );
  }

  @override
  void open(Map<String, dynamic> options) => _delegate.open(options);

  @override
  void clear() => _delegate.clear();

  /// Helper for web redirect flow.
  static Map<String, dynamic>? getStoredBookingData(String orderId) {
    if (kIsWeb) {
      return RazorpayServiceWeb.getStoredBookingData(orderId);
    }
    return null;
  }
}
