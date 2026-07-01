import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'auth_service.dart';
import 'subscription_service.dart';

enum IapStatus { pending, success, error, restored }

class IapStatusUpdate {
  final IapStatus status;
  final String message;

  const IapStatusUpdate(this.status, this.message);
}

class IapService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  static const String monthlyProductId = 'premium_monthly';
  static const String yearlyProductId = 'premium_yearly';

  static final StreamController<IapStatusUpdate> _statusController =
      StreamController<IapStatusUpdate>.broadcast();

  static Stream<IapStatusUpdate> get statusStream => _statusController.stream;

  static void _notify(IapStatusUpdate update) {
    _statusController.add(update);
  }

  static Future<void> init() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      return;
    }

    await _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onError: (error) {
        _notify(
          IapStatusUpdate(IapStatus.error, 'Purchase stream error: $error'),
        );
      },
    );
  }

  static Future<List<ProductDetails>> fetchProducts() async {
    final Set<String> kIds = <String>{monthlyProductId, yearlyProductId};
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(kIds);
    return response.productDetails;
  }

  static Future<void> buyProduct(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  static Future<void> restorePurchases() async {
    _notify(
      const IapStatusUpdate(IapStatus.pending, 'Restoring purchases…'),
    );
    await _iap.restorePurchases();
  }

  static Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _notify(
          const IapStatusUpdate(IapStatus.pending, 'Processing purchase…'),
        );
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        _notify(
          IapStatusUpdate(
            IapStatus.error,
            purchaseDetails.error?.message ?? 'Purchase failed.',
          ),
        );
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.canceled) {
        _notify(
          const IapStatusUpdate(IapStatus.error, 'Purchase canceled.'),
        );
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final delivered = await _deliverProduct(purchaseDetails);
        if (delivered && purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  static Future<bool> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final user = AuthService.currentUser;
    if (user == null) {
      _notify(
        const IapStatusUpdate(
          IapStatus.error,
          'Sign in required to activate Premium.',
        ),
      );
      return false;
    }

    final purchaseToken =
        purchaseDetails.verificationData.serverVerificationData;
    if (purchaseToken.isEmpty) {
      _notify(
        const IapStatusUpdate(
          IapStatus.error,
          'Missing purchase token from Google Play.',
        ),
      );
      return false;
    }

    try {
      final verification = await SubscriptionService.verify(
        productId: purchaseDetails.productID,
        purchaseToken: purchaseToken,
      );

      if (!verification.isPremium || verification.expiresAt == null) {
        _notify(
          IapStatusUpdate(
            IapStatus.error,
            verification.error ?? 'Subscription could not be verified.',
          ),
        );
        return false;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isPremium': true,
        'premiumExpiresAt': Timestamp.fromDate(verification.expiresAt!),
        'premiumProductId': verification.productId ?? purchaseDetails.productID,
        'purchaseToken': purchaseToken,
        'autoRenewing': verification.autoRenewing,
        'lastPurchaseId': purchaseDetails.purchaseID,
        'premiumUpdatedAt': FieldValue.serverTimestamp(),
      });

      final isRestore = purchaseDetails.status == PurchaseStatus.restored;
      _notify(
        IapStatusUpdate(
          isRestore ? IapStatus.restored : IapStatus.success,
          isRestore
              ? 'Premium restored successfully!'
              : 'Welcome to Voicecard Premium!',
        ),
      );
      return true;
    } catch (e) {
      _notify(
        IapStatusUpdate(IapStatus.error, 'Verification failed: $e'),
      );
      return false;
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
