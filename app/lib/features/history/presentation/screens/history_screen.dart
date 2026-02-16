import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../today/domain/entities/daily_reading.dart';
/// History screen — reading history for the last 7 (free) or 90 (premium) days.
///
/// DISCLAIMER: All past readings are for entertainment purposes only.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final hasPremium = ref.watch(hasPremiumAccessProvider);
    final historyDaysLimit = hasPremium ? 90 : 7;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B2A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFF0D0B2A),
              floating: true,
              title: const Text(
                'Reading History',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontFamily: 'Cinzel',
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
              centerTitle: true,
              automaticallyImplyLeading: false,
              actions: [
                if (!hasPremium)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: const Text(
                        '7 days free',
                        style: TextStyle(color: Color(0xFF6B6490), fontSize: 11),
                      ),
                      backgroundColor: const Color(0xFF1A1040),
                      side: BorderSide.none,
                    ),
                  ),
              ],
            ),

            if (profile == null)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Complete onboarding to see your history',
                    style: TextStyle(color: Color(0xFF6B6490), fontFamily: 'Raleway'),
                  ),
                ),
              )
            else
              _HistoryList(
                userId: profile.uid,
                zodiacSign: profile.zodiacSign,
                daysLimit: historyDaysLimit,
                hasPremium: hasPremium,
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({
    required this.userId,
    required this.zodiacSign,
    required this.daysLimit,
    required this.hasPremium,
  });

  final String userId;
  final String zodiacSign;
  final int daysLimit;
  final bool hasPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horoscopeRepo = ref.watch(horoscopeRepositoryProvider);

    return SliverFillRemaining(
      child: FutureBuilder(
        future: horoscopeRepo.getReadingHistory(
          userId: userId,
          zodiacSign: zodiacSign,
          days: daysLimit,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            );
          }

          final readings = snapshot.data ?? [];

          if (readings.isEmpty) {
            return _EmptyHistory();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: readings.length + (hasPremium ? 0 : 1),
            itemBuilder: (context, index) {
              // Free tier upgrade prompt at bottom
              if (!hasPremium && index == readings.length) {
                return _PremiumHistoryPromo();
              }
              return _HistoryCard(reading: readings[index]);
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.reading});
  final DailyReading reading;

  @override
  Widget build(BuildContext context) {
    final date = reading.date;
    final dateStr = '${_weekday(date.weekday)}, ${date.day} ${_month(date.month)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33C8BFFF)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF2D1B69),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 18),
        ),
        title: Text(
          dateStr,
          style: const TextStyle(
            color: Color(0xFFF8F4FF),
            fontFamily: 'Cinzel',
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          _capitalize(reading.zodiacSign),
          style: const TextStyle(color: Color(0xFF6B6490), fontSize: 12, fontFamily: 'Raleway'),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Color(0x33C8BFFF), height: 1),
                const SizedBox(height: 12),
                Text(
                  reading.horoscope.en,
                  style: const TextStyle(
                    color: Color(0xFFB8B0D4),
                    fontSize: 13,
                    fontFamily: 'Raleway',
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                _DisclaimerBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekday(int d) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  String _month(int m) => [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m - 1];
  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _DisclaimerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0B2A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '✦ For entertainment purposes only',
        style: TextStyle(
          color: Color(0xFF6B6490),
          fontSize: 10,
          fontFamily: 'Raleway',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_edu, color: Color(0xFF6B6490), size: 48),
          const SizedBox(height: 16),
          const Text(
            'No readings yet',
            style: TextStyle(
              color: Color(0xFFB8B0D4),
              fontFamily: 'Cinzel',
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your daily readings will appear here',
            style: TextStyle(
              color: Color(0xFF6B6490),
              fontFamily: 'Raleway',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumHistoryPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF2D1B69)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66D4AF37)),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFD4AF37), size: 28),
          const SizedBox(height: 8),
          const Text(
            'Access 90-day history with Premium',
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontFamily: 'Cinzel',
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO(stage4): Navigate to paywall
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF0D0B2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(fontFamily: 'Cinzel', letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
