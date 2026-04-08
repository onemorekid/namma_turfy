import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_service.dart';

/// Android / iOS implementation — delegates to the razorpay_flutter plugin.
class RazorpayServiceImpl implements RazorpayService {
  final Razorpay _razorpay = Razorpay();

  @override
  bool get requiresUserGesture => false;

  @override
  void setup({
    required OnPaymentSuccess onSuccess,
    required OnPaymentError onError,
    required OnExternalWallet onExternalWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      onSuccess(r.paymentId ?? '', r.orderId ?? '', r.signature ?? '');
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      onError(r.code, r.message);
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      onExternalWallet(r.walletName);
    });
  }

  @override
  void open(Map<String, dynamic> options) => _razorpay.open(options);

  @override
  void clear() => _razorpay.clear();
}
