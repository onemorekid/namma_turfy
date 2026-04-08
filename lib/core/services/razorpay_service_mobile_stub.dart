/// Stub used on non-web platforms so PaymentCallbackScreen compiles.
/// This screen is never shown on mobile (native app), so this is never called.
class RazorpayServiceImpl {
  static Map<String, dynamic>? getStoredBookingData(String orderId) => null;
}
