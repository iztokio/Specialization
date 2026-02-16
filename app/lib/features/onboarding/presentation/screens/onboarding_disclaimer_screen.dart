import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

/// Disclaimer Screen — ОБЯЗАТЕЛЬНЫЙ экран, нельзя пропустить.
///
/// SECURITY/COMPLIANCE:
/// - CTA заблокирован до прокрутки к концу
/// - Текст дисклеймера всегда полностью виден (нет truncate)
/// - Нельзя нажать "Назад" без принятия или выхода из онбординга
/// - Согласие логируется в Firebase Analytics

class OnboardingDisclaimerScreen extends ConsumerStatefulWidget {
  const OnboardingDisclaimerScreen({super.key});

  @override
  ConsumerState<OnboardingDisclaimerScreen> createState() =>
      _OnboardingDisclaimerScreenState();
}

class _OnboardingDisclaimerScreenState
    extends ConsumerState<OnboardingDisclaimerScreen> {
  bool _hasScrolledToBottom = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasScrolledToBottom) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      // Unlock when user has scrolled to 95% or more
      if (currentScroll >= maxScroll * 0.95) {
        setState(() => _hasScrolledToBottom = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent accidental back navigation
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitDialog(context);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.cosmicBackground,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                _DisclaimerHeader(),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DisclaimerIcon(),
                        const SizedBox(height: AppSpacing.lg),
                        _DisclaimerTitle(),
                        const SizedBox(height: AppSpacing.md),
                        _DisclaimerText(),
                        const SizedBox(height: AppSpacing.xl),
                        _PrivacyNote(),
                        const SizedBox(height: AppSpacing.xl),
                        // Scroll indicator
                        if (!_hasScrolledToBottom)
                          const _ScrollHint()
                        else
                          const _AllReadIndicator(),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),

                // Fixed CTA at bottom
                _DisclaimerCta(
                  enabled: _hasScrolledToBottom,
                  onAccept: () => _onAccept(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onAccept(BuildContext context) {
    // TODO(stage3): Save disclaimer acceptance to Firestore
    // TODO(stage3): Log analytics event: onboarding_disclaimer_accepted
    // TODO(stage3): GoRouter.of(context).push('/onboarding/notifications')
    Navigator.of(context).pop();
  }

  void _showExitDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cosmicPurple,
        title: const Text(
          'Exit Setup?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'You must accept the disclaimer to use AstraVia.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Setup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO(stage3): Exit to welcome screen
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.error,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMPONENTS
// ============================================================

class _DisclaimerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Progress indicator: step 4 of 5
          _ProgressDots(current: 4, total: 5),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i < current;
        return Container(
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? AppTheme.celestialGold
                : AppTheme.textDisabled.withAlpha(80),
          ),
        );
      }),
    );
  }
}

class _DisclaimerIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.warning.withAlpha(30),
          border: Border.all(color: AppTheme.warning.withAlpha(80)),
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          color: AppTheme.warning,
          size: 32,
        ),
      ),
    );
  }
}

class _DisclaimerTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Entertainment Only',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppTheme.warning,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Please read carefully before continuing',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DisclaimerText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO(l10n): Use AppLocalizations
    const disclaimerText = '''
This app is for ENTERTAINMENT PURPOSES ONLY.

AstraVia provides horoscopes and Tarot card readings as a form of entertainment and self-reflection. These readings are generated algorithmically and are not based on actual astrological or metaphysical expertise.

IMPORTANT: Nothing in this app constitutes:
• Medical or health advice
• Financial or investment advice
• Legal advice
• Psychological counseling
• Any other form of professional consultation

Results, readings, and interpretations provided by AstraVia are generated for entertainment purposes and should NOT be used as the basis for any real-world decisions affecting your health, finances, relationships, or legal matters.

If you have concerns about your health, finances, legal matters, or mental wellbeing, please consult a qualified professional.

By continuing, you acknowledge that you understand and accept these terms.
''';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.deepIndigo.withAlpha(150),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppTheme.celestialGold.withAlpha(40),
        ),
      ),
      child: Text(
        disclaimerText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.7,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '🔒 Your Privacy',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.celestialGold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We collect minimal data (birth date + preferences) to personalize your readings. We never sell your data. You can delete your account at any time.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ScrollHint extends StatelessWidget {
  const _ScrollHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.keyboard_arrow_down,
          color: AppTheme.textDisabled,
          size: 20,
        ),
        const SizedBox(width: 4),
        Text(
          'Scroll to continue',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textDisabled,
          ),
        ),
      ],
    );
  }
}

class _AllReadIndicator extends StatelessWidget {
  const _AllReadIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          color: AppTheme.success,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          'You\'ve read the disclaimer',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.success,
          ),
        ),
      ],
    );
  }
}

class _DisclaimerCta extends StatelessWidget {
  const _DisclaimerCta({required this.enabled, required this.onAccept});
  final bool enabled;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.midnightBlue.withAlpha(0),
            AppTheme.midnightBlue,
          ],
        ),
      ),
      child: Column(
        children: [
          AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: enabled ? onAccept : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      enabled ? AppTheme.celestialGold : AppTheme.textDisabled,
                  foregroundColor: AppTheme.midnightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  'I Understand — For Entertainment Only',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (!enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Scroll to the bottom to continue',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textDisabled,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
