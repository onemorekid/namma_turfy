typedef OnPaymentSuccess =
    void Function(String paymentId, String orderId, String signature);
typedef OnPaymentError = void Function(int? code, String? message);
typedef OnExternalWallet = void Function(String? walletName);

/// Platform-agnostic Razorpay interface.
/// Implemented by:
///   - razorpay_service_mobile.dart  (Android / iOS)
///   - razorpay_service_web.dart     (Flutter Web via JS interop)
abstract class RazorpayService {
  /// Web requires the SDK to be opened from a direct user-gesture handler
  /// (browser security). Native can open immediately after createOrder.
  bool get requiresUserGesture;

  void setup({
    required OnPaymentSuccess onSuccess,
    required OnPaymentError onError,
    required OnExternalWallet onExternalWallet,
  });

  void open(Map<String, dynamic> options);
  void clear();
}
