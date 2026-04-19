// Conditional export: the compiler picks the right file per platform.
// dart.library.js_interop is defined on Flutter Web (both JS and Wasm).
export 'razorpay_service_mobile.dart'
    if (dart.library.js_interop) 'razorpay_service_web.dart';
