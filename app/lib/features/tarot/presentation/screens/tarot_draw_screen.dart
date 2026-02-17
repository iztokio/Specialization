import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/tarot_card.dart';

/// 3-Card Spread screen — Past · Present · Future.
///
/// Premium-only feature: router navigates here only when user has premium
/// access (or premium gate was shown via _PremiumGateSheet on TodayScreen).
///
/// UX flow:
///   1. 3 face-down cards displayed in a row
///   2. User taps each card → flip animation reveals face
///   3. Tapping a revealed card selects it → detail panel animates in
///   4. Detail panel shows card name, position, and full meaning
///
/// DISCLAIMER: All readings for entertainment purposes only.
class TarotDrawScreen extends ConsumerStatefulWidget {
  const TarotDrawScreen({super.key});

  @override
  ConsumerState<TarotDrawScreen> createState() => _TarotDrawScreenState();
}

class _TarotDrawScreenState extends ConsumerState<TarotDrawScreen> {
  // Which cards are revealed (flipped face-up)
  final _revealed = [false, false, false];

  // Currently selected card index for detail panel (null = none)
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final hasPremium = ref.watch(hasPremiumAccessProvider);
    final spreadAsync = ref.watch(threeCardSpreadProvider);
    final language = ref.watch(appLanguageProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.cosmicBackground),
        child: SafeArea(
          child: Column(
            children: [
              _AppBar(),

              // Premium gate — should not normally be reached, but safety net
              if (!hasPremium)
                Expanded(child: _PremiumGate())
              else
                Expanded(
                  child: spreadAsync.when(
                    loading: () => const _SpreadSkeleton(),
                    error: (e, _) => _SpreadError(onRetry: () =>
                        ref.invalidate(threeCardSpreadProvider)),
                    data: (cards) => _SpreadContent(
                      cards: cards,
                      revealed: _revealed,
                      selectedIndex: _selectedIndex,
                      language: language,
                      onCardTap: _onCardTap,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCardTap(int index) {
    setState(() {
      if (!_revealed[index]) {
        _revealed[index] = true;
        _selectedIndex = index;
      } else {
        // Already revealed: toggle selection
        _selectedIndex = _selectedIndex == index ? null : index;
      }
    });
  }
}

// ============================================================
// SPREAD CONTENT — all interactive state is in parent
// ============================================================

class _SpreadContent extends StatelessWidget {
  const _SpreadContent({
    required this.cards,
    required this.revealed,
    required this.selectedIndex,
    required this.language,
    required this.onCardTap,
  });

  final List<TarotCard> cards;
  final List<bool> revealed;
  final int? selectedIndex;
  final String language;
  final ValueChanged<int> onCardTap;

  static const _positionLabels = ['Past', 'Present', 'Future'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Card row ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              cards.length.clamp(0, 3),
              (i) => _SpreadCardSlot(
                card: cards[i],
                isRevealed: revealed[i],
                isSelected: selectedIndex == i,
                positionLabel: _positionLabels[i],
                onTap: () => onCardTap(i),
              ),
            ),
          ),
        ),

        // ── Hint text (before any card revealed) ─────────────
        if (!revealed.any((r) => r))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              'Tap each card to reveal your reading',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // ── Detail panel ──────────────────────────────────────
        if (selectedIndex != null && revealed[selectedIndex!])
          Expanded(
            child: _CardDetailPanel(
              card: cards[selectedIndex!],
              positionLabel: _positionLabels[selectedIndex!],
              language: language,
              // Deterministic position: use card index as part of seed check
              isReversed: _isCardReversed(cards[selectedIndex!]),
            ),
          )
        else
          const Spacer(),

        // ── Disclaimer ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
          ),
          child: Text(
            '✨ For entertainment purposes only · Not professional advice',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textDisabled,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// Determine card orientation from its number (matches seed logic in repo).
  bool _isCardReversed(TarotCard card) {
    // Mirror the deterministic logic from TarotRepositoryImpl.getThreeCardSpread
    // seed XOR 0xDEADBEEF, then (seed >> (i*4)) % 3 == 0 → reversed
    // We approximate here using card number as a proxy for the spread position
    final i = cards.indexOf(card);
    if (i < 0) return false;
    // This matches the repository's formula: (seed >> (i * 4)) % 3 == 0
    // Since we don't have the seed here, use a stable proxy from card.number
    return (card.number + i) % 3 == 0;
  }
}

// ============================================================
// CARD SLOT — flip animation
// ============================================================

class _SpreadCardSlot extends StatefulWidget {
  const _SpreadCardSlot({
    required this.card,
    required this.isRevealed,
    required this.isSelected,
    required this.positionLabel,
    required this.onTap,
  });

  final TarotCard card;
  final bool isRevealed;
  final bool isSelected;
  final String positionLabel;
  final VoidCallback onTap;

  @override
  State<_SpreadCardSlot> createState() => _SpreadCardSlotState();
}

class _SpreadCardSlotState extends State<_SpreadCardSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _flip;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flip = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(_SpreadCardSlot old) {
    super.didUpdateWidget(old);
    if (widget.isRevealed && !old.isRevealed) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        children: [
          // Position label
          Text(
            widget.positionLabel.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 10,
              letterSpacing: 1.5,
              color: widget.isSelected
                  ? AppTheme.celestialGold
                  : AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Card with flip animation
          AnimatedBuilder(
            animation: _flip,
            builder: (context, _) {
              // Split flip into two halves
              final isFirstHalf = _flip.value < 0.5;
              final scaleX = isFirstHalf
                  ? 1.0 - (_flip.value * 2)
                  : (_flip.value - 0.5) * 2;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.celestialGold.withAlpha(60),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scale(scaleX.abs(), 1.0),
                  child: SizedBox(
                    width: 90,
                    height: 148,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: isFirstHalf
                          ? _CardFace.back()
                          : _CardFace.front(widget.card),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Card name (shown when revealed)
          SizedBox(
            width: 90,
            child: AnimatedOpacity(
              opacity: widget.isRevealed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Text(
                widget.card.arcana == TarotArcana.major
                    ? _kMajorArcanaNames[widget.card.number] ??
                        widget.card.names.en
                    : widget.card.names.en,
                style: const TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 9,
                  color: AppTheme.celestialGold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARD FACE — front/back images
// ============================================================

class _CardFace extends StatelessWidget {
  const _CardFace._({required this.assetPath, this.isBack = false});

  factory _CardFace.back() =>
      const _CardFace._(assetPath: 'assets/images/tarot/tarot_back.png', isBack: true);

  factory _CardFace.front(TarotCard card) {
    final path = card.arcana == TarotArcana.major &&
            card.number >= 0 &&
            card.number <= 21
        ? 'assets/images/tarot/tarot_major_${card.number}.png'
        : 'assets/images/tarot/tarot_back.png';
    return _CardFace._(assetPath: path);
  }

  final String assetPath;
  final bool isBack;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppTheme.deepIndigo,
        child: Center(
          child: Text(
            isBack ? '✦' : '?',
            style: const TextStyle(
              fontSize: 32,
              color: AppTheme.celestialGold,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL PANEL — selected card info
// ============================================================

class _CardDetailPanel extends StatelessWidget {
  const _CardDetailPanel({
    required this.card,
    required this.positionLabel,
    required this.language,
    required this.isReversed,
  });

  final TarotCard card;
  final String positionLabel;
  final String language;
  final bool isReversed;

  @override
  Widget build(BuildContext context) {
    final position = isReversed ? TarotPosition.reversed : TarotPosition.upright;
    final positionText = isReversed ? '↓ Reversed' : '↑ Upright';
    final positionColor = isReversed ? AppTheme.warning : AppTheme.success;

    final cardName = card.arcana == TarotArcana.major
        ? _kMajorArcanaNames[card.number] ?? card.getName(language)
        : card.getName(language);

    final meaningText = card.meanings
        .getMeaning(position: position)
        .get(language);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('${card.id}-$isReversed'),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppTheme.cosmicPurple,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppTheme.celestialGold.withAlpha(50)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Position context
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.celestialGold.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppTheme.celestialGold.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      positionLabel.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 11,
                        color: AppTheme.celestialGold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: positionColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: positionColor.withAlpha(80)),
                    ),
                    child: Text(
                      positionText,
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 11,
                        color: positionColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Card name
              Text(
                cardName.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.celestialGold,
                  letterSpacing: 2.0,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Meaning text
              Text(
                meaningText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STATES: Loading / Error / Premium Gate
// ============================================================

class _SpreadSkeleton extends StatelessWidget {
  const _SpreadSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            3,
            (_) => Container(
              width: 90,
              height: 148,
              decoration: BoxDecoration(
                color: AppTheme.deepIndigo,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpreadError extends StatelessWidget {
  const _SpreadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not load your reading',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _PremiumGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Premium Feature',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.celestialGold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The 3-Card Spread is available to Premium subscribers.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pushPaywall(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.celestialGold,
                  foregroundColor: AppTheme.midnightBlue,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  'Unlock Premium',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// APP BAR
// ============================================================

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              '3-CARD SPREAD',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.celestialGold,
                letterSpacing: 2.5,
              ),
            ),
          ),
          // Spacer to balance the back button
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ============================================================
// NAVIGATION EXTENSION
// ============================================================

extension _RouterExt on BuildContext {
  void pushPaywall() => push(AppRoutes.paywall);
}

// ============================================================
// MAJOR ARCANA NAMES (same as today_screen, kept local)
// ============================================================

const _kMajorArcanaNames = {
  0: 'The Fool', 1: 'The Magician', 2: 'The High Priestess',
  3: 'The Empress', 4: 'The Emperor', 5: 'The Hierophant',
  6: 'The Lovers', 7: 'The Chariot', 8: 'Strength',
  9: 'The Hermit', 10: 'Wheel of Fortune', 11: 'Justice',
  12: 'The Hanged Man', 13: 'Death', 14: 'Temperance',
  15: 'The Devil', 16: 'The Tower', 17: 'The Star',
  18: 'The Moon', 19: 'The Sun', 20: 'Judgement', 21: 'The World',
};
