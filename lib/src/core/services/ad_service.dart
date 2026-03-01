import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdService {
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Test ID
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test ID
  
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isLoaded = false;
  
  bool get isBannerLoaded => _bannerAd != null && _isLoaded;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
      ),
    );
  }

  Future<BannerAd> loadBannerAd() async {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          _isLoaded = true;
          debugPrint('Banner ad loaded');
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
        },
        onAdOpened: (Ad ad) {
          debugPrint('Banner ad opened');
        },
        onAdClosed: (Ad ad) {
          debugPrint('Banner ad closed');
        },
      ),
    );
    
    await _bannerAd!.load();
    return _bannerAd!;
  }

  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          debugPrint('Interstitial ad loaded');
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          debugPrint('Interstitial ad dismissed');
          ad.dispose();
          _interstitialAd = null;
          // Load next ad
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('Interstitial ad failed to show: $error');
          ad.dispose();
          _interstitialAd = null;
        },
      );
      await _interstitialAd!.show();
    } else {
      debugPrint('Interstitial ad not loaded yet');
      // Try to load and show
      await loadInterstitialAd();
      if (_interstitialAd != null) {
        await _interstitialAd!.show();
      }
    }
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
  }
}
