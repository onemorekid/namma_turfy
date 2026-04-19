import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'razorpay_service.dart';

@JS('openRazorpay')
external void _openRazorpayJS(
  JSObject options,
  JSFunction onSuccess,
  JSFunction onError,
);

@JS('storeRazorpayBookingData')
external void _storeRazorpayBookingDataJS(JSString orderId, JSObject meta);

@JS('getRazorpayBookingData')
external JSObject? _getRazorpayBookingDataJS(JSString orderId);

@JS('_isMobileBrowser')
external JSBoolean _isMobileBrowserJS();

/// Flutter Web implementation — delegates to the Razorpay JS SDK
/// via the JS bridge function defined in web/index.html.
class RazorpayServiceWeb implements RazorpayService {
  OnPaymentSuccess? _onSuccess;
  OnPaymentError? _onError;
  OnExternalWallet? _onExternalWallet;

  // Match the logic in web/index.html for redirect flow.
  static bool get _isMobile =>
      _isMobileBrowserJS().toDart || web.window.innerWidth <= 768;

  @override
  bool get requiresUserGesture => true;

  @override
  void setup({
    required OnPaymentSuccess onSuccess,
    required OnPaymentError onError,
    required OnExternalWallet onExternalWallet,
  }) {
    _onSuccess = onSuccess;
    _onError = onError;
    _onExternalWallet = onExternalWallet;
  }

  @override
  void open(Map<String, dynamic> options) {
    // Extract and strip booking metadata injected by CheckoutScreen.
    final meta = options['_bookingMeta'] as Map<String, dynamic>?;
    final cleanOptions = Map<String, dynamic>.from(options)
      ..remove('_bookingMeta');

    if (_isMobile && meta != null) {
      final orderId = cleanOptions['order_id'] as String? ?? '';
      _storeRazorpayBookingDataJS(orderId.toJS, meta.jsify()! as JSObject);
    }

    final successFn = _onSuccess;
    final errorFn = _onError;

    final successCb =
        ((JSString paymentId, JSString orderId, JSString signature) {
          successFn?.call(paymentId.toDart, orderId.toDart, signature.toDart);
        }).toJS;

    final errorCb = ((JSNumber code, JSString message) {
      errorFn?.call(code.toDartDouble.toInt(), message.toDart);
    }).toJS;

    _openRazorpayJS(cleanOptions.jsify()! as JSObject, successCb, errorCb);
  }

  /// Read back booking metadata stored before the mobile redirect.
  static Map<String, dynamic>? getStoredBookingData(String orderId) {
    final result = _getRazorpayBookingDataJS(orderId.toJS);
    if (result == null) return null;
    return (result.dartify() as Map?)?.cast<String, dynamic>();
  }

  @override
  void clear() {}
}
