import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Onboarding Step 3: Notification opt-in.
///
/// Asks user to enable daily cosmic reading notifications.
/// Can be skipped — notification permission is never forced.
///
/// After this screen: onboarding is COMPLETE → navigate to home.
class OnboardingNotificationsScreen extends ConsumerStatefulWidget {
  const OnboardingNotificationsScreen({super.key});

  @override
  ConsumerState<OnboardingNotificationsScreen> createState() =>
      _OnboardingNotificationsScreenState();
}

class _OnboardingNotificationsScreenState
    extends ConsumerState<OnboardingNotificationsScreen> {
  bool _isLoading = false;

  Future<void> _onEnable() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(notificationServiceProvider);
      await service.requestPermission();
      await service.scheduleDailyNotification(
        notificationTitle: '✦ Your Daily Reading is Ready',
        notificationBody: 'The stars have a message for you today.',
        time: '09:00',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    await _completeOnboarding();
  }

  Future<void> _onSkip() async {
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    // Use authUserIdProvider — always non-null ('local_user_fallback' offline).
    // currentUserIdProvider reads from userProfileProvider which may not be
    // refreshed yet at this point in the onboarding flow.
    final userId = ref.read(authUserIdProvider);
    await ref.read(userProfileRepositoryProvider).completeOnboarding(userId);
    ref.invalidate(userProfileProvider);
    if (!mounted) return;
    // GoRouter redirect fires automatically once userProfileProvider reloads
    // with onboardingDone = true. The explicit go() handles the race case.
    context.go(AppRoutes.today);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),

              // ── Step indicator ──
              _NotifStepIndicator(),

              const Spacer(),

              // ── Illustration ──
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.royalPurple.withValues(alpha: 0.3),
                  border: Border.all(
                    color: AppTheme.celestialGold.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  size: 56,
                  color: AppTheme.celestialGold,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Title ──
              Text(
                'Daily Cosmic Updates',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                'Get notified when your daily horoscope and tarot reading are ready. '
                'We send only one notification per day.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Notification preview card ──
              _NotifPreviewCard(),

              const Spacer(),

              // ── Enable button ──
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _onEnable,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.midnightBlue,
                          ),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: const Text('Enable Notifications'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.celestialGold,
                    foregroundColor: AppTheme.midnightBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Skip ──
              TextButton(
                onPressed: _isLoading ? null : _onSkip,
                child: Text(
                  'Maybe later',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
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

class _NotifStepIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.celestialGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _NotifPreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cosmicPurple,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppTheme.celestialGold.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.royalPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('✦', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✦ Your Daily Reading is Ready',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The stars have a message for you today.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
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
