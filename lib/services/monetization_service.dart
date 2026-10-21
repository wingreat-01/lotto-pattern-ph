import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Monetization helpers for rewarded generation and the one-time ad-free unlock.
/// Replace the test ad unit with your own AdMob rewarded unit before release.
class MonetizationService extends ChangeNotifier {
  MonetizationService._() {
    _purchaseSubscription = _billing.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (_) => _purchaseError = 'Could not verify the purchase. Please try again.',
    );
    _restoreLocalState();
  }

  static final MonetizationService instance = MonetizationService._();
  static const String lifetimeProductId = 'lottopattern_lifetime_199';
  // LottoPattern PH production rewarded-ad unit. Use Google's test unit during development.
  static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  final InAppPurchase _billing = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  RewardedAd? _rewardedAd;
  ProductDetails? _lifetimeProduct;
  bool _premium = false;
  bool _busy = false;
  String? _purchaseError;

  bool get isPremium => _premium;
  bool get isBusy => _busy;
  String? get purchaseError => _purchaseError;
  ProductDetails? get lifetimeProduct => _lifetimeProduct;
  String get lifetimePrice => _lifetimeProduct?.price ?? '₱199';

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    await _loadRewardedAd();
    await loadProducts();
  }

  Future<void> _loadRewardedAd() async {
    if (_rewardedAd != null) return;
    final completer = Completer<void>();
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    await completer.future;
  }

  /// Returns true only after the user earns the reward by completing the ad.
  Future<bool> showRewardedAd() async {
    if (_premium) return true;
    var earned = false;
    final ad = _rewardedAd;
    if (ad == null) {
      await _loadRewardedAd();
      if (_rewardedAd == null) return false;
    }
    final readyAd = _rewardedAd!;
    final completer = Completer<bool>();
    readyAd.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    readyAd.show(onUserEarnedReward: (_, __) { earned = true; });
    return completer.future;
  }

  Future<void> loadProducts() async {
    try {
      final available = await _billing.isAvailable();
      if (!available) return;
      final response = await _billing.queryProductDetails({lifetimeProductId});
      if (response.productDetails.isNotEmpty) {
        _lifetimeProduct = response.productDetails.first;
        notifyListeners();
      }
      if (response.error != null) _purchaseError = response.error!.message;
    } catch (_) {
      _purchaseError = 'Could not load the lifetime purchase. Please try again later.';
    }
    notifyListeners();
  }

  Future<bool> buyLifetime() async {
    if (_busy) return false;
    await loadProducts();
    final product = _lifetimeProduct;
    if (product == null) {
      _purchaseError = 'Lifetime purchase is not available yet. Please try again later.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _purchaseError = null;
    notifyListeners();
    try {
      await _billing.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      // Purchase result is delivered asynchronously through purchaseStream.
      return true;
    } catch (_) {
      _purchaseError = 'Could not start the purchase. Please try again.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    _busy = true;
    _purchaseError = null;
    notifyListeners();
    try {
      await _billing.restorePurchases();
    } catch (_) {
      _purchaseError = 'Could not restore purchases. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _restoreLocalState() {
    // Ask Google Play to emit previously owned non-consumable purchases through
    // purchaseStream. This is the supported cross-platform restore mechanism.
    _billing.restorePurchases().catchError((_) {});
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID == lifetimeProductId &&
          (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored)) {
        // TODO production: verify purchase.verificationData.serverVerificationData
        // with a trusted backend before granting permanent entitlement.
        _premium = true;
        _purchaseError = null;
      } else if (purchase.status == PurchaseStatus.error) {
        _purchaseError = purchase.error?.message ?? 'Purchase failed. Please try again.';
      }
      if (purchase.pendingCompletePurchase) {
        _billing.completePurchase(purchase);
      }
    }
    _busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _rewardedAd?.dispose();
    super.dispose();
  }
}
