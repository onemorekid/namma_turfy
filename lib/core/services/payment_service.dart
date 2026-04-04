import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return MockPaymentService();
});

abstract class PaymentService {
  Future<bool> processPayment({
    required double amount,
    required String name,
    required String email,
    required String description,
  });
}

class MockPaymentService implements PaymentService {
  @override
  Future<bool> processPayment({
    required double amount,
    required String name,
    required String email,
    required String description,
  }) async {
    // In production: initialize Razorpay, open checkout, handle events.
    await Future.delayed(const Duration(seconds: 2));
    return true; // Simulate successful payment
  }
}
