import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

/// Onboarding Welcome Screen — первый экран после установки.
///
/// UX Goals:
/// - Впечатляющий visual first impression
/// - Быстрый CTA — не задерживать пользователя
/// - Mini disclaimer виден сразу
class OnboardingWelcomeScreen extends ConsumerWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.cosmicBackground,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                // Top spacer
                SizedBox(height: size.height * 0.08),

                // Hero: Star animation placeholder (Lottie in Stage 3)
                _StarHero(size: size.height * 0.28),

                SizedBox(height: size.height * 0.05),

                // App name
                const Text(
                  '✦ ASTRAVIA ✦',
                  style: TextStyle(
                    fontFamily: 'CinzelDecorative',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.celestialGold,
                    letterSpacing: 4.0,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.md),

                // Tagline
                Text(
                  // TODO(l10n): AppLocalizations.of(context)!.onboardingWelcomeTitle
                  'Your stars. Your story.\nEvery day.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // CTA Button
                _WelcomeCta(onTap: () => _onGetStarted(context)),

                const SizedBox(height: AppSpacing.md),

                // Secondary action
                TextButton(
                  onPressed: () => _onSignIn(context),
                  child: Text(
                    'Already have an account? Sign in',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Disclaimer — always visible
                _DisclaimerFooter(),

                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onGetStarted(BuildContext context) {
    // TODO(stage3): GoRouter.of(context).push('/onboarding/birthdate')
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _BirthdatePlaceholder(),
      ),
    );
  }

  void _onSignIn(BuildContext context) {
    // TODO(stage3): Firebase Auth sign in
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign in — coming in Stage 3'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================
// COMPONENTS
// ============================================================

class _StarHero extends StatefulWidget {
  const _StarHero({required this.size});
  final double size;

  @override
  State<_StarHero> createState() => _StarHeroState();
}

class _StarHeroState extends State<_StarHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulse.value,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.celestialGold.withAlpha(30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Inner glow
            Container(
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.celestialGold.withAlpha(50),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Star symbol
            const Text(
              '✦',
              style: TextStyle(
                fontSize: 80,
                color: AppTheme.celestialGold,
              ),
            ),
            // Orbit dots
            ..._buildOrbitDots(widget.size / 2 - 16),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOrbitDots(double radius) {
    const count = 8;
    return List.generate(count, (i) {
      final angle = (i * 2 * 3.14159265) / count;
      final x = radius * 0.7 * (1 + 0.1 * (i % 2 == 0 ? 1 : -1));
      final y = radius * 0.7;
      return Positioned(
        left: (widget.size / 2) + x * (angle < 3.14 ? 1 : -1) * 0.5,
        top: (widget.size / 2) + y * (i < count / 2 ? -1 : 1) * 0.4,
        child: Container(
          width: i % 3 == 0 ? 4 : 2,
          height: i % 3 == 0 ? 4 : 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.celestialGold.withAlpha(i % 2 == 0 ? 200 : 120),
          ),
        ),
      );
    });
  }
}

class _WelcomeCta extends StatelessWidget {
  const _WelcomeCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.celestialGold,
          foregroundColor: AppTheme.midnightBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 8,
          shadowColor: AppTheme.celestialGold.withAlpha(80),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Begin Your Journey',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cosmicPurple.withAlpha(80),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppTheme.celestialGold.withAlpha(40),
        ),
      ),
      child: Text(
        '⭐ For entertainment purposes only · Not professional advice',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textDisabled,
          fontSize: 10,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// Temporary placeholder — will be replaced with GoRouter in Stage 3
class _BirthdatePlaceholder extends StatelessWidget {
  const _BirthdatePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Birth Date')),
      body: const Center(
        child: Text('Birth Date Screen — Stage 3'),
      ),
    );
  }
}
