import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class IapService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Placeholder IDs - User must replace these in Google Play Console
  static const String monthlyProductId = 'premium_monthly';
  static const String yearlyProductId = 'premium_yearly';

  static Future<void> init() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      print("IAP not available");
      return;
    }

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      print("IAP Stream Error: $error");
    });
  }

  static Future<List<ProductDetails>> fetchProducts() async {
    final Set<String> kIds = <String>{monthlyProductId, yearlyProductId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(kIds);
    if (response.notFoundIDs.isNotEmpty) {
      print("Products not found: ${response.notFoundIDs}");
    }
    return response.productDetails;
  }

  static void buyProduct(ProductDetails product) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  static Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  static void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          print("Purchase Error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          await _deliverProduct(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  static Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    // Determine expiration based on product ID
    DateTime expiresAt;
    if (purchaseDetails.productID == monthlyProductId) {
      expiresAt = DateTime.now().add(const Duration(days: 30));
    } else if (purchaseDetails.productID == yearlyProductId) {
      expiresAt = DateTime.now().add(const Duration(days: 365));
    } else {
      expiresAt = DateTime.now().add(const Duration(days: 30)); // fallback
    }

    // Update Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isPremium': true,
      'premiumExpiresAt': Timestamp.fromDate(expiresAt),
      'lastPurchaseId': purchaseDetails.purchaseID,
    });
  }

  static void dispose() {
    _subscription.cancel();
  }
}
