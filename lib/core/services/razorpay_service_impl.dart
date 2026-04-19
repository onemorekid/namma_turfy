// Conditional export: the compiler picks the right file per platform.
// For Wasm compatibility, we default to the web implementation
// and only export the mobile implementation when dart.library.io is available.
export 'razorpay_service_web.dart'
    if (dart.library.io) 'razorpay_service_mobile.dart';
