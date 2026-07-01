import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/iap_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _monthly = true;
  bool _isPurchasing = false;
  StreamSubscription<IapStatusUpdate>? _iapSubscription;

  @override
  void initState() {
    super.initState();
    _iapSubscription = IapService.statusStream.listen(_handleIapStatus);
  }

  @override
  void dispose() {
    _iapSubscription?.cancel();
    super.dispose();
  }

  void _handleIapStatus(IapStatusUpdate update) {
    if (!mounted) return;

    setState(() {
      _isPurchasing = update.status == IapStatus.pending;
    });

    switch (update.status) {
      case IapStatus.pending:
        break;
      case IapStatus.success:
      case IapStatus.restored:
        _showSnack(update.message);
        break;
      case IapStatus.error:
        _showSnack(update.message);
        break;
    }
  }

  String _priceFor(List<ProductDetails> products, String productId, String fallback) {
    for (final product in products) {
      if (product.id == productId) {
        return product.price;
      }
    }
    return fallback;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
void _signInAndSubscribe(List<ProductDetails> products) async {
  final user = AuthService.currentUser;
  if (user == null) {
    final credential = await AuthService.signInWithGoogle();
    if (credential == null) {
      _showSnack('Sign in canceled.');
      return;
    }
  }

  if (products.isEmpty) {
    _showSnack('Products not available.');
    return;
  }

  final targetId = _monthly
      ? IapService.monthlyProductId
      : IapService.yearlyProductId;
      
ProductDetails? product;
try {
  product = products.firstWhere((p) => p.id == targetId);
} catch (_) {
  product = null;
}

if (product == null) {
  _showSnack('Product not found. Please try again.');
  return;
}

IapService.buyProduct(product);
  setState(() => _isPurchasing = true);
}
  @override
  Widget build(BuildContext context) {
    // Check real-time premium status
    final userDoc = ref.watch(userDocProvider).value;
    final isPremium =
        userDoc != null &&
        userDoc.exists &&
        userDoc.data()?['isPremium'] == true;

    if (isPremium || ref.watch(settingsProvider).isActivePremium) {
      return _buildAlreadyPremium(context);
    }

    final productsAsync = ref.watch(iapProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      PhosphorIconsLight.x,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    // Amber glow orb
                    Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.amberDim.withValues(alpha: 0.3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.amber.withValues(alpha: 0.25),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            PhosphorIconsFill.crown,
                            size: 36,
                            color: AppColors.amber,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.06, 1.06),
                          duration: 2000.ms,
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(height: 24),
                    Text(
                      'Voicecard Premium',
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Your notes. Everywhere.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 36),

                    // Features
                    ..._features.asMap().entries.map(
                      (e) => _FeatureRow(
                        icon: e.value.$1,
                        label: e.value.$2,
                        index: e.key,
                      ),
                    ),
                    const SizedBox(height: 36),

                    productsAsync.when(
                      data: (products) => Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                _BillingTab(
                                  label: 'Monthly',
                                  price: _priceFor(
                                    products,
                                    IapService.monthlyProductId,
                                    '₹99 / mo',
                                  ),
                                  selected: _monthly,
                                  onTap: () => setState(() => _monthly = true),
                                ),
                                _BillingTab(
                                  label: 'Yearly',
                                  price: _priceFor(
                                    products,
                                    IapService.yearlyProductId,
                                    '₹799 / yr',
                                  ),
                                  badge: 'Save 33%',
                                  selected: !_monthly,
                                  onTap: () => setState(() => _monthly = false),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 400.ms),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isPurchasing
                                  ? null
                                  : () => _signInAndSubscribe(products),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.amber,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isPurchasing
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _monthly
                                          ? 'Start Premium — ${_priceFor(products, IapService.monthlyProductId, '₹99/mo')}'
                                          : 'Start Premium — ${_priceFor(products, IapService.yearlyProductId, '₹799/yr')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 500.ms),
                        ],
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.amber,
                        ),
                      ),
                      error: (err, stack) => Text(
                        'Error loading products: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cancel anytime. No questions asked.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 550.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyPremium(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIconsFill.crown,
                  size: 64,
                  color: AppColors.amber,
                ),
                const SizedBox(height: 16),
                Text(
                  'You\'re Premium!',
                  style: Theme.of(context).textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enjoy unlimited notes and cloud sync.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final _features = [
    (PhosphorIconsLight.infinity, 'Unlimited notes'),
    (
      PhosphorIconsLight.cloudArrowUp,
      'Secure cloud backup',
    ),
    (PhosphorIconsLight.devices, 'Multi-device access'),
    (PhosphorIconsLight.headset, 'Priority support'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child:
          Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.amber),
                  ),
                  const SizedBox(width: 14),
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                ],
              )
              .animate(delay: Duration(milliseconds: 200 + 80 * index))
              .fadeIn()
              .slideX(begin: -0.08),
    );
  }
}

class _BillingTab extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _BillingTab({
    required this.label,
    required this.price,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.amber.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected
                          ? AppColors.amber
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.amber),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? AppColors.amberLight : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
