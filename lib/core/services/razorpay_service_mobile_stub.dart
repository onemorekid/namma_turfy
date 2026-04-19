import 'razorpay_service.dart';

/// Stub used on non-web platforms so PaymentCallbackScreen compiles.
/// Also used on Web to avoid importing razorpay_flutter.
class RazorpayServiceMobile implements RazorpayService {
  @override
  bool get requiresUserGesture => false;

  @override
  void setup({
    required OnPaymentSuccess onSuccess,
    required OnPaymentError onError,
    required OnExternalWallet onExternalWallet,
  }) {}

  @override
  void open(Map<String, dynamic> options) {}

  @override
  void clear() {}

  static Map<String, dynamic>? getStoredBookingData(String orderId) => null;
}
