import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/app_router.dart';

/// Settings screen — language, notifications, theme, legal, account.
///
/// DISCLAIMER: Entertainment purposes only — shown in legal section.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final hasPremium = ref.watch(hasPremiumAccessProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B2A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFF0D0B2A),
              floating: true,
              title: const Text(
                'Settings',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontFamily: 'Cinzel',
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
              centerTitle: true,
              automaticallyImplyLeading: false,
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                // ─── Premium status banner ────────────────────────────
                if (hasPremium)
                  _PremiumBadge()
                else
                  _UpgradeBanner(onTap: () => context.push(AppRoutes.paywall)),

                // ─── Preferences ──────────────────────────────────────
                _SectionHeader(title: 'Preferences'),

                _SettingsTile(
                  icon: Icons.language,
                  title: 'Language',
                  value: _languageLabel(profile?.preferredLanguage ?? 'en'),
                  onTap: () => _showLanguagePicker(context),
                ),

                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Daily Reminder',
                  value: profile?.notificationTime ?? AppConstants.defaultNotificationTime,
                  onTap: () => _showTimePicker(context),
                ),

                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme',
                  value: 'Dark (Cosmic)',
                  onTap: null, // TODO(stage3): theme toggle
                ),

                // ─── Your Reading ─────────────────────────────────────
                _SectionHeader(title: 'Your Reading'),

                _SettingsTile(
                  icon: Icons.cake_outlined,
                  title: 'Birth Date',
                  value: profile != null
                      ? '${profile.birthDate.day}/${profile.birthDate.month}/${profile.birthDate.year}'
                      : 'Not set',
                  onTap: null, // Locked after onboarding for data integrity
                ),

                _SettingsTile(
                  icon: Icons.auto_awesome,
                  title: 'Zodiac Sign',
                  value: _capitalize(profile?.zodiacSign ?? 'Unknown'),
                  onTap: null,
                ),

                // ─── Legal ────────────────────────────────────────────
                _SectionHeader(title: 'Legal'),

                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Entertainment Disclaimer',
                  value: 'For entertainment purposes only',
                  onTap: () => _showDisclaimer(context),
                ),

                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  value: null,
                  onTap: () {/* TODO(stage5): open URL */},
                ),

                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  value: null,
                  onTap: () {/* TODO(stage5): open URL */},
                ),

                // ─── Subscription ─────────────────────────────────────
                _SectionHeader(title: 'Subscription'),

                if (!hasPremium)
                  _SettingsTile(
                    icon: Icons.star_outline,
                    title: 'Upgrade to Premium',
                    value: null,
                    onTap: () => context.push(AppRoutes.paywall),
                    accent: true,
                  ),

                _SettingsTile(
                  icon: Icons.restore,
                  title: 'Restore Purchases',
                  value: null,
                  onTap: () => _restorePurchases(context),
                ),

                // ─── Account ──────────────────────────────────────────
                _SectionHeader(title: 'Account'),

                _SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'Delete Account & Data',
                  value: null,
                  onTap: () => _confirmDeleteAccount(context),
                  destructive: true,
                ),

                const SizedBox(height: 16),
                _AppVersionFooter(),
                const SizedBox(height: 32),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1040),
      builder: (ctx) => _LanguagePicker(
        onSelected: (lang) {
          // TODO(stage3): Update profile language
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showTimePicker(BuildContext context) async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    final parts = (profile?.notificationTime ?? '09:00').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;

    // TODO(stage3): Update profile notificationTime + reschedule notification
  }

  void _showDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1040),
        title: const Text(
          'Entertainment Disclaimer',
          style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Cinzel'),
        ),
        content: const Text(
          'AstraLume is designed exclusively for entertainment purposes. '
          'All horoscope readings and Tarot interpretations are creative '
          'content generated for enjoyment only.\n\n'
          'They do NOT constitute:\n'
          '• Medical advice or diagnosis\n'
          '• Financial or investment advice\n'
          '• Legal advice\n'
          '• Psychological counselling\n'
          '• Any form of professional guidance\n\n'
          'Always consult qualified professionals for important life decisions.',
          style: TextStyle(color: Color(0xFFB8B0D4), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand', style: TextStyle(color: Color(0xFFD4AF37))),
          ),
        ],
      ),
    );
  }

  void _restorePurchases(BuildContext context) {
    // TODO(stage4): Call SubscriptionRepository.restore()
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restore purchases — available in Stage 4'),
        backgroundColor: Color(0xFF1A1040),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1040),
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Color(0xFFEF4444), fontFamily: 'Cinzel'),
        ),
        content: const Text(
          'This will permanently delete all your readings, settings, and account data. '
          'This action cannot be undone.',
          style: TextStyle(color: Color(0xFFB8B0D4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6490))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO(stage3): ref.read(userProfileRepositoryProvider).deleteAllData(userId)
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  String _languageLabel(String code) => switch (code) {
    'en' => 'English',
    'es' => 'Español',
    'pt' => 'Português',
    'ru' => 'Русский',
    _ => code,
  };

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6B6490),
          fontSize: 11,
          letterSpacing: 2,
          fontFamily: 'Raleway',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.accent = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool accent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive
        ? const Color(0xFFEF4444)
        : accent
            ? const Color(0xFFD4AF37)
            : const Color(0xFFF8F4FF);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, color: const Color(0xFF9B8FE8), size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontSize: 15,
          fontFamily: 'Raleway',
        ),
      ),
      trailing: value != null
          ? Text(
              value!,
              style: const TextStyle(
                color: Color(0xFF6B6490),
                fontSize: 13,
                fontFamily: 'Raleway',
              ),
            )
          : onTap != null
              ? const Icon(Icons.chevron_right, color: Color(0xFF6B6490), size: 20)
              : null,
      onTap: onTap,
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF2D1B69)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4C1D95)),
      ),
      child: const Row(
        children: [
          Icon(Icons.star, color: Color(0xFFD4AF37), size: 20),
          SizedBox(width: 12),
          Text(
            'AstraLume Premium',
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontFamily: 'Cinzel',
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1040), Color(0xFF0D0B2A)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66D4AF37)),
        ),
        child: const Row(
          children: [
            Icon(Icons.star_outline, color: Color(0xFFD4AF37), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Upgrade to Premium — Unlock all readings',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontFamily: 'Raleway'),
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF6B6490), size: 18),
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.onSelected});
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    final langs = [
      ('en', 'English', '🇬🇧'),
      ('es', 'Español', '🇪🇸'),
      ('pt', 'Português', '🇧🇷'),
      ('ru', 'Русский', '🇷🇺'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Choose Language',
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontFamily: 'Cinzel',
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...langs.map((l) => ListTile(
          leading: Text(l.$3, style: const TextStyle(fontSize: 24)),
          title: Text(l.$2, style: const TextStyle(color: Color(0xFFF8F4FF), fontFamily: 'Raleway')),
          onTap: () => onSelected(l.$1),
        )),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AppVersionFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          const Text(
            'AstraLume v${AppConstants.appVersion}',
            style: TextStyle(color: Color(0xFF6B6490), fontSize: 12, fontFamily: 'Raleway'),
          ),
          const SizedBox(height: 4),
          const Text(
            'For entertainment purposes only',
            style: TextStyle(color: Color(0xFF6B6490), fontSize: 11, fontFamily: 'Raleway'),
          ),
        ],
      ),
    );
  }
}
