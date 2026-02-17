import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user_profile.dart';

/// Onboarding Step 2: Birth Date selection.
///
/// Collects birth date → calculates zodiac sign → saves UserProfile to DB.
/// After this screen: disclaimer → notifications → home.
///
/// COPPA: minimum age 13 enforced (AppConstants.minimumAge).
class OnboardingBirthdateScreen extends ConsumerStatefulWidget {
  const OnboardingBirthdateScreen({super.key});

  @override
  ConsumerState<OnboardingBirthdateScreen> createState() =>
      _OnboardingBirthdateScreenState();
}

class _OnboardingBirthdateScreenState
    extends ConsumerState<OnboardingBirthdateScreen> {
  DateTime? _selectedDate;
  String? _zodiacSign;
  bool _isSaving = false;

  static const _zodiacEmojis = {
    'aries': '♈',
    'taurus': '♉',
    'gemini': '♊',
    'cancer': '♋',
    'leo': '♌',
    'virgo': '♍',
    'libra': '♎',
    'scorpio': '♏',
    'sagittarius': '♐',
    'capricorn': '♑',
    'aquarius': '♒',
    'pisces': '♓',
  };

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _zodiacSign = ZodiacCalculator.getSign(date);
    });
  }

  Future<void> _onContinue() async {
    final date = _selectedDate;
    if (date == null) return;

    final error = UserProfile.validateBirthDate(date);
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = ref.read(authUserIdProvider);
      final profile = UserProfile.fromOnboarding(
        uid: userId,
        birthDate: date,
      );
      await ref.read(userProfileRepositoryProvider).saveProfile(profile);
      // Don't invalidate userProfileProvider here — onboardingDone is still
      // false, so invalidation would cause a loading→splash redirect loop.
      // The router re-evaluates when completeOnboarding() is called later.

      if (!mounted) return;
      context.push(AppRoutes.onboardingDisclaimer);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ??
        DateTime(now.year - 25, now.month, now.day); // sensible default

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year - AppConstants.minimumAge, now.month, now.day),
      helpText: 'Select your birth date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.celestialGold,
            onPrimary: AppTheme.midnightBlue,
            surface: AppTheme.cosmicPurple,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) _onDateSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = _selectedDate != null;
    final zodiac = _zodiacSign;
    final emoji = zodiac != null ? (_zodiacEmojis[zodiac] ?? '✦') : null;

    return Scaffold(
      backgroundColor: AppTheme.midnightBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textSecondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // ── Step indicator ──
              _StepIndicator(current: 1, total: 3),
              const SizedBox(height: AppSpacing.xl),

              // ── Title ──
              Text(
                'When were you born?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your birth date reveals your zodiac sign and personalizes your cosmic readings.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Date picker button ──
              _DatePickerButton(
                selectedDate: _selectedDate,
                onTap: _pickDate,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Zodiac reveal ──
              if (hasDate && zodiac != null) ...[
                _ZodiacReveal(zodiacSign: zodiac, emoji: emoji!),
              ],

              const Spacer(),

              // ── CTA ──
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: hasDate && !_isSaving ? _onContinue : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.celestialGold,
                    foregroundColor: AppTheme.midnightBlue,
                    disabledBackgroundColor:
                        AppTheme.celestialGold.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.midnightBlue,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontFamily: 'Raleway',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Components ──────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.celestialGold
                  : AppTheme.textDisabled.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({this.selectedDate, required this.onTap});
  final DateTime? selectedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = selectedDate;
    final label = d == null
        ? 'Tap to select date'
        : '${d.day.toString().padLeft(2, '0')} / '
            '${d.month.toString().padLeft(2, '0')} / '
            '${d.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppTheme.cosmicPurple,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: d != null
                ? AppTheme.celestialGold.withValues(alpha: 0.6)
                : AppTheme.textDisabled.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: d != null ? AppTheme.celestialGold : AppTheme.textDisabled,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: d != null
                        ? AppTheme.textPrimary
                        : AppTheme.textDisabled,
                    letterSpacing: d != null ? 2.0 : 0,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZodiacReveal extends StatelessWidget {
  const _ZodiacReveal({required this.zodiacSign, required this.emoji});
  final String zodiacSign;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final name =
        zodiacSign[0].toUpperCase() + zodiacSign.substring(1);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.royalPurple, AppTheme.deepIndigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppTheme.celestialGold.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your sign',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.celestialGold,
                        fontFamily: 'Cinzel',
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
