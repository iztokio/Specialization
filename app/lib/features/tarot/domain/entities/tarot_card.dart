import 'package:equatable/equatable.dart';

/// Tarot card entity.
///
/// DISCLAIMER: All card meanings are for entertainment purposes only.
/// This is NOT spiritual guidance, psychological advice, or any other
/// form of professional consultation.

enum TarotArcana { major, minor }

enum TarotSuit { cups, wands, swords, pentacles, none }

enum TarotPosition { upright, reversed }

class TarotCard extends Equatable {
  const TarotCard({
    required this.id,
    required this.number,
    required this.arcana,
    required this.suit,
    required this.names,
    required this.imageUrl,
    required this.imageLicense,
    required this.imageSource,
    required this.meanings,
    required this.version,
  });

  final String id; // e.g. "major_00_fool", "cups_01_ace"
  final int number; // 0-21 for major, 1-14 for minor
  final TarotArcana arcana;
  final TarotSuit suit;
  final LocalizedText names;
  final String imageUrl;
  final String imageLicense; // REQUIRED: "CC0 1.0", "OFL 1.1", etc.
  final String imageSource;  // REQUIRED: URL or attribution
  final TarotMeanings meanings;
  final int version;

  /// Get name for current locale
  String getName(String languageCode) => names.get(languageCode);

  @override
  List<Object?> get props => [id, number, arcana, suit, version];
}

/// Multilingual text container
class LocalizedText extends Equatable {
  const LocalizedText({
    required this.en,
    required this.es,
    required this.pt,
    required this.ru,
  });

  final String en;
  final String es;
  final String pt;
  final String ru;

  String get(String languageCode) {
    return switch (languageCode) {
      'es' => es,
      'pt' => pt,
      'ru' => ru,
      _ => en,
    };
  }

  @override
  List<Object?> get props => [en, es, pt, ru];
}

/// Card meanings — ENTERTAINMENT ONLY disclaimer embedded in data structure
class TarotMeanings extends Equatable {
  const TarotMeanings({
    required this.upright,
    required this.reversed,
    required this.love,
    required this.work,
    required this.health,
  });

  final LocalizedText upright;   // General upright meaning
  final LocalizedText reversed;  // General reversed meaning
  final LocalizedText love;      // Love/relationships context (entertainment)
  final LocalizedText work;      // Work/career context (entertainment)
  final LocalizedText health;    // Wellbeing context (entertainment, NOT medical advice)

  LocalizedText getMeaning({
    required TarotPosition position,
    String? category, // 'love' | 'work' | 'health' | null
  }) {
    if (category != null) {
      return switch (category) {
        'love' => love,
        'work' => work,
        'health' => health,
        _ => position == TarotPosition.upright ? upright : reversed,
      };
    }
    return position == TarotPosition.upright ? upright : reversed;
  }

  @override
  List<Object?> get props => [upright, reversed, love, work, health];
}

/// A drawn card with position (upright/reversed)
class DrawnCard extends Equatable {
  const DrawnCard({
    required this.card,
    required this.position,
    required this.spreadPosition, // 0=past/left, 1=present/center, 2=future/right
  });

  final TarotCard card;
  final TarotPosition position;
  final int spreadPosition;

  @override
  List<Object?> get props => [card, position, spreadPosition];
}
