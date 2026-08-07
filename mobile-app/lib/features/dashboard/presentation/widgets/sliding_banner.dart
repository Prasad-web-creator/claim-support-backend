import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BannerItemData {
  final String imageAsset;
  final String targetUrl;

  const BannerItemData({
    required this.imageAsset,
    required this.targetUrl,
  });
}

class SlidingBanner extends StatefulWidget {
  const SlidingBanner({super.key});

  @override
  State<SlidingBanner> createState() => _SlidingBannerState();
}

class _SlidingBannerState extends State<SlidingBanner> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  // Widescreen Ad Banners with Website Redirection Links
  final List<BannerItemData> _banners = const [ 
    BannerItemData(
      imageAsset: 'assets/ad_banner_1_new.png', // Banner 1: Accounts Guru
      targetUrl: 'https://accountsguru.io/',
    ),
    BannerItemData(
      imageAsset: 'assets/ad_banner_2_new.png', // Banner 2: Retail One
      targetUrl: 'https://retailone.cloud/',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    if (_banners.length > 1) {
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (_banners.length <= 1) return;
    
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _launchBannerUrl(String url) async {
    final uri = Uri.parse(url);
    debugPrint('[SlidingBanner] Attempting to open URL: $url');
    
    try {
      // Primary Attempt: Launch in external browser
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        // Fallback Attempt: Launch in platform default browser
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      debugPrint('[SlidingBanner] Primary launch error ($e), trying fallback...');
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } catch (fallbackErr) {
        debugPrint('[SlidingBanner] Fallback launch error ($fallbackErr) for URL: $url');
      }
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // PageView Banner Container with Minute Edge Padding & Touch Redirection
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double bannerWidth = constraints.maxWidth;
              final double bannerHeight = (bannerWidth / 2.2).clamp(150.0, 190.0);

              return Container(
                height: bannerHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _banners.length,
                  itemBuilder: (context, index) {
                    return _buildBannerCard(_banners[index]);
                  },
                ),
              );
            },
          ),
        ),

        // Page Indicator Dots
        if (_banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: isActive ? 20 : 6,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildBannerCard(BannerItemData banner) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _launchBannerUrl(banner.targetUrl),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF030A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            banner.imageAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF1E293B),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 36),
                    SizedBox(height: 6),
                    Text(
                      'Banner Image Failed to Load',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
