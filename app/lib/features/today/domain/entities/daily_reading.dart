import 'package:equatable/equatable.dart';
import 'package:mystic_tarot/features/tarot/domain/entities/tarot_card.dart';

/// Daily reading entity — the core "today" content.
///
/// DISCLAIMER: For entertainment purposes only. Not professional advice.
///
/// IMPORTANT: The reading is deterministic for a given date + zodiac sign.
/// The same user will see the same reading regardless of how many times
/// they open the app on the same day. This prevents "rerolling" for
/// a "better" reading and maintains integrity.

class DailyReading extends Equatable {
  const DailyReading({
    required this.id,
    required this.uid,
    required this.date,
    required this.zodiacSign,
    required this.horoscope,
    required this.drawnCards,
    required this.seed,
    required this.contentVersion,
    required this.language,
    required this.isPremium,
    required this.createdAt,
  });

  final String id; // "{uid}_{date_yyyy-MM-dd}"
  final String uid;
  final DateTime date;          // Date-only (no time)
  final String zodiacSign;
  final LocalizedText horoscope; // Multilingual horoscope text
  final List<DrawnCard> drawnCards; // 1 card (free) or 3 cards (premium)
  final int seed;               // Deterministic seed for this date+sign
  final int contentVersion;     // Content version used to generate
  final String language;        // User's language at time of generation
  final bool isPremium;         // Was this a premium reading?
  final DateTime createdAt;

  /// Generate deterministic seed for a given date and zodiac sign
  static int generateSeed(DateTime date, String zodiacSign) {
    // Combine date components + zodiac sign into a repeatable integer
    // This ensures the same reading every time for same date+sign
    final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final signIndex = [
      'aries', 'taurus', 'gemini', 'cancer',
      'leo', 'virgo', 'libra', 'scorpio',
      'sagittarius', 'capricorn', 'aquarius', 'pisces',
    ].indexOf(zodiacSign);

    // Simple deterministic hash (not crypto — just for card selection)
    var hash = int.parse(dateStr);
    hash = hash ^ (signIndex * 1000000);
    hash = hash ^ (hash >> 13);
    hash = hash * 0x5bd1e995;
    hash = hash ^ (hash >> 15);
    return hash.abs();
  }

  /// Select N cards deterministically from a deck, excluding recently shown cards
  static List<int> selectCardIndices({
    required int seed,
    required int count,
    required int totalCards,
    List<int> excludeIndices = const [],
  }) {
    final available = List.generate(totalCards, (i) => i)
      ..removeWhere(excludeIndices.contains);

    if (available.length < count) {
      // Fall back to full deck if exclusions make count impossible
      return _selectFromList(
        seed: seed,
        list: List.generate(totalCards, (i) => i),
        count: count,
      );
    }

    return _selectFromList(seed: seed, list: available, count: count);
  }

  static List<int> _selectFromList({
    required int seed,
    required List<int> list,
    required int count,
  }) {
    final mutable = List<int>.from(list);
    final selected = <int>[];
    var currentSeed = seed;

    for (var i = 0; i < count && mutable.isNotEmpty; i++) {
      currentSeed = (currentSeed * 1664525 + 1013904223) & 0xFFFFFFFF;
      final index = currentSeed % mutable.length;
      selected.add(mutable[index]);
      mutable.removeAt(index);
    }

    return selected;
  }

  /// Check if today's reading has already been created
  static String makeId(String uid, DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${uid}_$dateStr';
  }

  DailyReading copyWith({
    String? id,
    String? uid,
    DateTime? date,
    String? zodiacSign,
    LocalizedText? horoscope,
    List<DrawnCard>? drawnCards,
    int? seed,
    int? contentVersion,
    String? language,
    bool? isPremium,
    DateTime? createdAt,
  }) {
    return DailyReading(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      date: date ?? this.date,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      horoscope: horoscope ?? this.horoscope,
      drawnCards: drawnCards ?? this.drawnCards,
      seed: seed ?? this.seed,
      contentVersion: contentVersion ?? this.contentVersion,
      language: language ?? this.language,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, uid, date, zodiacSign, contentVersion];
}
