// Conditional export: the compiler picks the right file per platform.
// dart.library.html is only defined on Flutter Web.
export 'razorpay_service_mobile.dart'
    if (dart.library.html) 'razorpay_service_web.dart';
