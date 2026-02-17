import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

/// Paywall Screen — Premium subscription offer.
///
/// UX Strategy:
/// 1. Benefits first (value), price second
/// 2. Annual plan highlighted as default (Best Value)
/// 3. Trial CTA if trial available
/// 4. Transparent pricing and cancellation policy
/// 5. Disclaimer visible (не скрываем в мелком тексте)
///
/// COMPLIANCE:
/// - Disclaimer всегда виден
/// - Условия отмены на виду
/// - Restore purchases доступен
/// - Entertainment disclaimer в footer

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.featureContext});

  /// Optional: which premium feature triggered this paywall
  /// Used for A/B testing and analytics
  final String? featureContext;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isYearlySelected = true; // Default: yearly (best value)
  bool _isPurchasing = false;

  @override
  Widget build(BuildContext context) {
    // TODO(stage4): Load real prices from in_app_purchase plugin
    const monthlyPrice = r'$4.99';
    const yearlyPrice = r'$29.99';
    const yearlyPricePerMonth = r'$2.50';
    const savingsPercent = 50;
    const trialDays = 3;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.cosmicBackground,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Close button
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _CloseButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),

                    // Hero
                    const _PaywallHero(),

                    // Feature list
                    const _FeatureList(),

                    const SizedBox(height: AppSpacing.lg),

                    // Pricing toggle
                    _PricingToggle(
                      isYearlySelected: _isYearlySelected,
                      monthlyPrice: monthlyPrice,
                      yearlyPrice: yearlyPrice,
                      yearlyPricePerMonth: yearlyPricePerMonth,
                      savingsPercent: savingsPercent,
                      onToggle: (isYearly) =>
                          setState(() => _isYearlySelected = isYearly),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // CTA
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: _PaywallCta(
                        hasTrial: trialDays > 0,
                        trialDays: trialDays,
                        isPurchasing: _isPurchasing,
                        onSubscribe: () => _onSubscribe(context),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Restore purchases
                    TextButton(
                      onPressed: _isPurchasing ? null : () => _onRestore(context),
                      child: Text(
                        'Restore Purchases',
                        // TODO(l10n): AppLocalizations.of(context)!.paywallRestore
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Legal footer
                    const _PaywallLegalFooter(),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),

              // Loading overlay
              if (_isPurchasing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.celestialGold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSubscribe(BuildContext context) async {
    if (_isPurchasing) return;

    setState(() => _isPurchasing = true);

    try {
      // TODO(stage4): Implement Google Play Billing
      // final productId = _isYearlySelected
      //     ? AppConstants.subscriptionYearlyId
      //     : AppConstants.subscriptionMonthlyId;
      // await ref.read(subscriptionRepositoryProvider).purchase(productId);

      // Placeholder
      await Future<void>.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase flow — coming in Stage 4'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _onRestore(BuildContext context) async {
    // TODO(stage4): Implement restore purchases via Cloud Functions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restore purchases — coming in Stage 4'),
      ),
    );
  }
}

// ============================================================
// COMPONENTS
// ============================================================

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.deepIndigo,
          border: Border.all(
            color: AppTheme.celestialGold.withAlpha(60),
          ),
        ),
        child: const Icon(
          Icons.close,
          color: AppTheme.textSecondary,
          size: 18,
        ),
      ),
    );
  }
}

class _PaywallHero extends StatelessWidget {
  const _PaywallHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          // Gold star
          const Text('✦', style: TextStyle(fontSize: 48, color: AppTheme.celestialGold)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Unlock Your Full Potential',
            // TODO(l10n): AppLocalizations.of(context)!.paywallTitle
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppTheme.celestialGold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Premium gives you deeper cosmic insights',
            // TODO(l10n): AppLocalizations.of(context)!.paywallSubtitle
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _features = [
    (icon: '🃏', text: '3-Card Tarot Spreads'),
    (icon: '📖', text: '90 Days Reading History'),
    (icon: '✨', text: 'Detailed Card Meanings'),
    (icon: '💫', text: 'Love, Work & Wellbeing Insights'),
    (icon: '🚫', text: 'No Ads'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.cosmicPurple,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppTheme.celestialGold.withAlpha(50),
          ),
        ),
        child: Column(
          children: _features.map((f) => _FeatureRow(f.icon, f.text)).toList(),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.icon, this.text);
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.check,
            color: AppTheme.celestialGold,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _PricingToggle extends StatelessWidget {
  const _PricingToggle({
    required this.isYearlySelected,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.yearlyPricePerMonth,
    required this.savingsPercent,
    required this.onToggle,
  });

  final bool isYearlySelected;
  final String monthlyPrice;
  final String yearlyPrice;
  final String yearlyPricePerMonth;
  final int savingsPercent;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _PricingCard(
              label: 'Monthly',
              price: monthlyPrice,
              subtitle: 'per month',
              isSelected: !isYearlySelected,
              onTap: () => onToggle(false),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _PricingCard(
                  label: 'Yearly',
                  price: yearlyPrice,
                  subtitle: '$yearlyPricePerMonth/mo',
                  isSelected: isYearlySelected,
                  onTap: () => onToggle(true),
                ),
                // Best Value badge
                Positioned(
                  top: -10,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.celestialGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Save $savingsPercent%',
                      style: const TextStyle(
                        color: AppTheme.midnightBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Raleway',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.label,
    required this.price,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String price;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.celestialGold.withAlpha(20)
              : AppTheme.deepIndigo,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? AppTheme.celestialGold
                : AppTheme.celestialGold.withAlpha(40),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSelected
                    ? AppTheme.celestialGold
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppTheme.celestialGold
                    : AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallCta extends StatelessWidget {
  const _PaywallCta({
    required this.hasTrial,
    required this.trialDays,
    required this.isPurchasing,
    required this.onSubscribe,
  });

  final bool hasTrial;
  final int trialDays;
  final bool isPurchasing;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final ctaText = hasTrial
        ? 'Start $trialDays-Day Free Trial'
        : 'Subscribe Now';

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isPurchasing ? null : onSubscribe,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.celestialGold,
          foregroundColor: AppTheme.midnightBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 8,
          shadowColor: AppTheme.celestialGold.withAlpha(80),
        ),
        child: isPurchasing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.midnightBlue,
                  strokeWidth: 2,
                ),
              )
            : Text(
                ctaText,
                style: const TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class _PaywallLegalFooter extends StatelessWidget {
  const _PaywallLegalFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          Text(
            'Cancel anytime. Subscription renews automatically.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '⭐ For entertainment purposes only. Results may vary.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textDisabled,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
