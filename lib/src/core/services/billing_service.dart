import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';

class BillingService extends ChangeNotifier {
  static const String proProductId = 'batch_pdf_pro';
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  bool _isPro = false;
  
  bool get isPro => _isPro;

  Future<void> initialize() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      debugPrint('In-app purchases not available');
      return;
    }

    // Listen to purchase updates
    _inAppPurchase.purchaseStream.listen(_handlePurchaseUpdates);
    
    // Load products
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = 
        await _inAppPurchase.queryProductDetails({proProductId});
    
    if (response.error != null) {
      debugPrint('Error loading products: ${response.error}');
      return;
    }

    if (response.productDetails.isEmpty) {
      debugPrint('No products found');
      return;
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        _isPro = true;
        notifyListeners();
        debugPrint('Pro purchased!');
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<bool> purchasePro() async {
    // In production, you'd fetch the ProductDetails first
    // For now, return false to indicate the purchase flow would start
    try {
      final ProductDetailsResponse response = 
          await _inAppPurchase.queryProductDetails({proProductId});
      
      if (response.productDetails.isNotEmpty) {
        final ProductDetails product = response.productDetails.first;
        final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
        return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
      return false;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  void setProStatus(bool value) {
    _isPro = value;
    notifyListeners();
  }
}
