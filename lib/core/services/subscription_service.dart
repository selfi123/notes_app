import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_api.dart';

class SubscriptionVerificationResult {
  final bool isPremium;
  final DateTime? expiresAt;
  final String? productId;
  final bool autoRenewing;
  final String? error;

  const SubscriptionVerificationResult({
    required this.isPremium,
    this.expiresAt,
    this.productId,
    this.autoRenewing = false,
    this.error,
  });
}

class SubscriptionService {
  static Future<SubscriptionVerificationResult> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    final response = await http.post(
      Uri.parse('${BackendApi.baseUrl}/verify-subscription'),
      headers: BackendApi.headers,
      body: jsonEncode({
        'packageName': BackendApi.packageName,
        'productId': productId,
        'purchaseToken': purchaseToken,
      }),
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return SubscriptionVerificationResult(
        isPremium: false,
        error: 'Invalid server response (${response.statusCode})',
      );
    }

    if (response.statusCode == 401) {
      return SubscriptionVerificationResult(
        isPremium: false,
        error: 'Server authentication failed.',
      );
    }

    final expiresAtMillis = data['expiresAtMillis'];
    DateTime? expiresAt;
    if (expiresAtMillis is int) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMillis);
    } else if (data['expiresAt'] is String) {
      expiresAt = DateTime.tryParse(data['expiresAt'] as String);
    }

    final isPremium = data['isPremium'] == true || data['valid'] == true;

    return SubscriptionVerificationResult(
      isPremium: isPremium,
      expiresAt: expiresAt,
      productId: data['productId'] as String?,
      autoRenewing: data['autoRenewing'] == true,
      error: isPremium ? null : (data['error'] as String? ?? 'Subscription not active.'),
    );
  }
}
