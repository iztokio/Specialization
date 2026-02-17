import '../../domain/entities/tarot_card.dart';

/// Bundled local tarot card data — full 78-card deck.
///
/// Major Arcana (0–21): full multilingual names + meanings.
/// Minor Arcana (22–77): generated algorithmically from suit/rank templates.
///
/// This is the offline-first fallback used when Firestore is unavailable
/// or card library hasn't been fetched yet.
///
/// DISCLAIMER: All meanings are for entertainment purposes only.
class TarotLocalDatasource {
  TarotLocalDatasource._();

  static final TarotLocalDatasource instance = TarotLocalDatasource._();

  // ─── Public API ────────────────────────────────────────────────────────────

  /// All 78 cards. Built once and cached.
  late final List<TarotCard> allCards = _buildDeck();

  TarotCard? getByIndex(int index) {
    if (index < 0 || index >= allCards.length) return null;
    return allCards[index];
  }

  List<TarotCard> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return allCards;
    return allCards.where((c) {
      return c.names.en.toLowerCase().contains(q) ||
          c.names.ru.toLowerCase().contains(q) ||
          c.suit.name.contains(q);
    }).toList();
  }

  // ─── Deck builder ──────────────────────────────────────────────────────────

  List<TarotCard> _buildDeck() {
    return [
      ..._majorArcana,
      ..._buildMinorArcana(),
    ];
  }

  // ─── Major Arcana (0–21) ───────────────────────────────────────────────────

  static final List<TarotCard> _majorArcana = [
    _major(0, 'The Fool', 'El Loco', 'O Louco', 'Шут',
        upEn: 'New beginnings, innocence, spontaneity, free spirit. A leap of faith into the unknown.',
        upEs: 'Nuevos comienzos, inocencia, espontaneidad. Un salto de fe hacia lo desconocido.',
        upPt: 'Novos começos, inocência, espontaneidade. Um salto de fé no desconhecido.',
        upRu: 'Новые начала, невинность, спонтанность. Прыжок веры в неизвестность.',
        revEn: 'Recklessness, being taken advantage of, inconsistency, naivety.',
        revEs: 'Imprudencia, ser aprovechado, inconsistencia, ingenuidad.',
        revPt: 'Imprudência, ingenuidade, inconsistência.',
        revRu: 'Безрассудство, непоследовательность, наивность.',
        loveEn: 'An exciting new relationship or a fresh start in love. Be open to unexpected connections.',
        workEn: 'A bold new career move or creative venture. Trust your instincts and take that leap.',
        healthEn: 'Embrace an active, adventurous lifestyle. Listen to your body\'s need for freedom.'),
    _major(1, 'The Magician', 'El Mago', 'O Mago', 'Маг',
        upEn: 'Manifestation, resourcefulness, power, inspired action. You have all the tools you need.',
        upEs: 'Manifestación, ingenio, poder. Tienes todas las herramientas que necesitas.',
        upPt: 'Manifestação, habilidade, poder. Você tem todas as ferramentas necessárias.',
        upRu: 'Проявление, находчивость, сила. У вас есть всё необходимое.',
        revEn: 'Manipulation, poor planning, untapped talents. Skills left unused.',
        revEs: 'Manipulación, mala planificación, talentos sin usar.',
        revPt: 'Manipulação, má planificação, talentos desperdiçados.',
        revRu: 'Манипуляция, плохое планирование, нереализованные таланты.',
        loveEn: 'You hold the power to create the relationship you desire. Be intentional with your actions.',
        workEn: 'Your skills and talents are ready to be put to work. Seize opportunities with confidence.',
        healthEn: 'You have the willpower to make positive health changes. Mind over matter.'),
    _major(2, 'The High Priestess', 'La Suma Sacerdotisa', 'A Alta Sacerdotisa', 'Верховная Жрица',
        upEn: 'Intuition, sacred knowledge, divine feminine, the subconscious. Trust your inner voice.',
        upEs: 'Intuición, conocimiento sagrado, lo divino femenino. Confía en tu voz interior.',
        upPt: 'Intuição, conhecimento sagrado, o divino feminino. Confie na sua voz interior.',
        upRu: 'Интуиция, сакральное знание, подсознание. Доверяйте своему внутреннему голосу.',
        revEn: 'Secrets, disconnected from intuition, withdrawal, silence.',
        revEs: 'Secretos, desconexión de la intuición, silencio.',
        revPt: 'Segredos, desconexão da intuição, silêncio.',
        revRu: 'Тайны, оторванность от интуиции, молчание.',
        loveEn: 'There is more beneath the surface in your love life. Patience and intuition will reveal the truth.',
        workEn: 'Trust your instincts in professional decisions. Not everything is as it appears.',
        healthEn: 'Listen to your body\'s subtle signals. Quiet reflection supports your wellbeing.'),
    _major(3, 'The Empress', 'La Emperatriz', 'A Imperatriz', 'Императрица',
        upEn: 'Femininity, beauty, nature, nurturing, abundance. A time of growth and fertility.',
        upEs: 'Feminidad, belleza, naturaleza, abundancia. Un tiempo de crecimiento.',
        upPt: 'Feminilidade, beleza, natureza, abundância. Um tempo de crescimento.',
        upRu: 'Женственность, красота, природа, изобилие. Время роста и плодородия.',
        revEn: 'Creative block, dependence on others, smothering energy.',
        revEs: 'Bloqueo creativo, dependencia, energía sofocante.',
        revPt: 'Bloqueio criativo, dependência, energia sufocante.',
        revRu: 'Творческий застой, зависимость, подавляющая энергия.',
        loveEn: 'Nurturing energy surrounds your relationships. Love is abundant and growing.',
        workEn: 'Creative and financial abundance is available to you. Trust in your creative power.',
        healthEn: 'Connect with nature and nurture your body with care and rest.'),
    _major(4, 'The Emperor', 'El Emperador', 'O Imperador', 'Император',
        upEn: 'Authority, establishment, structure, father figure. Build strong foundations.',
        upEs: 'Autoridad, estructura, figura paterna. Construye bases sólidas.',
        upPt: 'Autoridade, estrutura, figura paterna. Construa bases sólidas.',
        upRu: 'Власть, структура, авторитет. Создавайте прочные основы.',
        revEn: 'Domination, inflexibility, lack of discipline, father issues.',
        revEs: 'Dominación, inflexibilidad, falta de disciplina.',
        revPt: 'Dominação, inflexibilidade, falta de disciplina.',
        revRu: 'Доминирование, негибкость, недостаток дисциплины.',
        loveEn: 'Stability and commitment are highlighted. Create a secure foundation in your relationship.',
        workEn: 'Take charge and lead with confidence. Structure and planning lead to success.',
        healthEn: 'Establish healthy routines and stick to them with discipline.'),
    _major(5, 'The Hierophant', 'El Sumo Sacerdote', 'O Hierofante', 'Иерофант',
        upEn: 'Spiritual wisdom, tradition, conformity, morality. Seek guidance from established wisdom.',
        upEs: 'Sabiduría espiritual, tradición, conformidad. Busca orientación.',
        upPt: 'Sabedoria espiritual, tradição. Busque orientação estabelecida.',
        upRu: 'Духовная мудрость, традиция. Ищите наставление в проверенной мудрости.',
        revEn: 'Personal beliefs, freedom, challenging the status quo.',
        revEs: 'Creencias personales, libertad, desafiar el statu quo.',
        revPt: 'Crenças pessoais, liberdade, desafiar o status quo.',
        revRu: 'Личные убеждения, свобода, вызов устоям.',
        loveEn: 'Shared values and traditions strengthen your bond. Consider what you truly believe in together.',
        workEn: 'Working within established systems brings success. Seek a mentor or advisor.',
        healthEn: 'Traditional healing practices may benefit you. Seek expert guidance.'),
    _major(6, 'The Lovers', 'Los Amantes', 'Os Amantes', 'Влюблённые',
        upEn: 'Love, harmony, relationships, values alignment, choices. Follow your heart.',
        upEs: 'Amor, armonía, relaciones, alineación de valores. Sigue tu corazón.',
        upPt: 'Amor, harmonia, relacionamentos. Siga seu coração.',
        upRu: 'Любовь, гармония, отношения, выбор. Следуйте своему сердцу.',
        revEn: 'Disharmony, imbalance, misalignment of values, difficulty with choices.',
        revEs: 'Desarmonía, desequilibrio, dificultad con las elecciones.',
        revPt: 'Desarmonia, desequilíbrio, dificuldade com escolhas.',
        revRu: 'Дисгармония, дисбаланс, трудности с выбором.',
        loveEn: 'Deep connection and meaningful choices in love. A significant relationship milestone approaches.',
        workEn: 'A major career decision aligns with your deepest values. Choose what truly resonates.',
        healthEn: 'Balance and harmony in body and mind. Make choices that truly serve your wellbeing.'),
    _major(7, 'The Chariot', 'El Carro', 'O Carro', 'Колесница',
        upEn: 'Control, willpower, success, action, determination. Victory through focused effort.',
        upEs: 'Control, fuerza de voluntad, éxito. Victoria a través del esfuerzo enfocado.',
        upPt: 'Controle, força de vontade, sucesso. Vitória através do esforço focado.',
        upRu: 'Контроль, сила воли, успех. Победа через целенаправленные усилия.',
        revEn: 'Lack of control, lack of direction, aggression, obstacles.',
        revEs: 'Falta de control, falta de dirección, obstáculos.',
        revPt: 'Falta de controle, falta de direção, obstáculos.',
        revRu: 'Потеря контроля, отсутствие направления, препятствия.',
        loveEn: 'Take the driver\'s seat in your love life. Pursue what you want with determination.',
        workEn: 'A decisive push toward your goals will bring victory. Maintain focus and drive.',
        healthEn: 'Your willpower is strong. Channel it into consistent healthy habits.'),
    _major(8, 'Strength', 'La Fuerza', 'A Força', 'Сила',
        upEn: 'Strength, courage, patience, control, compassion. Inner strength overcomes challenges.',
        upEs: 'Fuerza, coraje, paciencia, compasión. La fortaleza interior supera los desafíos.',
        upPt: 'Força, coragem, paciência, compaixão. A força interior supera os desafios.',
        upRu: 'Сила, мужество, терпение, сострадание. Внутренняя сила преодолевает трудности.',
        revEn: 'Inner strength, self-doubt, low energy, raw emotion.',
        revEs: 'Fuerza interior, autoduda, baja energía, emoción cruda.',
        revPt: 'Força interior, autodúvida, baixa energia, emoção bruta.',
        revRu: 'Внутренняя сила, сомнения в себе, низкая энергия.',
        loveEn: 'Patience and understanding are your greatest tools in love. Lead with compassion.',
        workEn: 'Face challenges with quiet confidence. Your resilience is your superpower.',
        healthEn: 'Your inner strength supports your healing. Trust in your body\'s natural resilience.'),
    _major(9, 'The Hermit', 'El Ermitaño', 'O Eremita', 'Отшельник',
        upEn: 'Soul-searching, introspection, being alone, inner guidance. Wisdom found in solitude.',
        upEs: 'Introspección, estar solo, guía interior. Sabiduría encontrada en la soledad.',
        upPt: 'Introspecção, estar só, orientação interior. Sabedoria encontrada na solidão.',
        upRu: 'Самоанализ, уединение, внутреннее руководство. Мудрость, найденная в одиночестве.',
        revEn: 'Isolation, loneliness, withdrawal, lost your way.',
        revEs: 'Aislamiento, soledad, retirada, perdido tu camino.',
        revPt: 'Isolamento, solidão, retirada, perdido o seu caminho.',
        revRu: 'Изоляция, одиночество, отстранённость, потеря пути.',
        loveEn: 'Take time for self-reflection before seeking connection. Know yourself first.',
        workEn: 'A period of focused, independent work brings enlightenment. Trust your inner guidance.',
        healthEn: 'Rest and introspection are healing. Give yourself permission to slow down.'),
    _major(10, 'Wheel of Fortune', 'La Rueda de la Fortuna', 'A Roda da Fortuna', 'Колесо Фортуны',
        upEn: 'Good luck, karma, life cycles, destiny, a turning point. Embrace the winds of change.',
        upEs: 'Buena suerte, karma, ciclos de vida, destino. Abraza los vientos del cambio.',
        upPt: 'Boa sorte, karma, ciclos de vida, destino. Abrace as mudanças.',
        upRu: 'Удача, карма, жизненные циклы, судьба. Примите перемены.',
        revEn: 'Bad luck, resistance to change, breaking cycles.',
        revEs: 'Mala suerte, resistencia al cambio, ruptura de ciclos.',
        revPt: 'Má sorte, resistência à mudança, ruptura de ciclos.',
        revRu: 'Неудача, сопротивление переменам, разрыв циклов.',
        loveEn: 'Fate is at work in your love life. An unexpected twist brings exciting possibilities.',
        workEn: 'Fortune favors you professionally. A lucky break or unexpected opportunity is turning the wheel.',
        healthEn: 'Health cycles are shifting. A positive turning point is on the horizon.'),
    _major(11, 'Justice', 'La Justicia', 'A Justiça', 'Справедливость',
        upEn: 'Justice, fairness, truth, cause and effect, law. Actions have consequences.',
        upEs: 'Justicia, equidad, verdad, causa y efecto. Las acciones tienen consecuencias.',
        upPt: 'Justiça, equidade, verdade, causa e efeito. As ações têm consequências.',
        upRu: 'Справедливость, честность, истина, причина и следствие.',
        revEn: 'Unfairness, lack of accountability, dishonesty.',
        revEs: 'Injusticia, falta de responsabilidad, deshonestidad.',
        revPt: 'Injustiça, falta de responsabilidade, desonestidade.',
        revRu: 'Несправедливость, безответственность, нечестность.',
        loveEn: 'Honest communication creates balance in your relationship. Treat others as you wish to be treated.',
        workEn: 'Fair decisions and integrity pave the way for professional success.',
        healthEn: 'Balance is key to your health. Honest self-assessment leads to real change.'),
    _major(12, 'The Hanged Man', 'El Colgado', 'O Enforcado', 'Повешенный',
        upEn: 'Pause, surrender, letting go, new perspectives. Sometimes waiting is the wisest action.',
        upEs: 'Pausa, rendición, soltar, nuevas perspectivas. A veces esperar es la acción más sabia.',
        upPt: 'Pausa, rendição, novas perspectivas. Às vezes esperar é a ação mais sábia.',
        upRu: 'Пауза, принятие, новые перспективы. Иногда ожидание — самый мудрый выбор.',
        revEn: 'Delays, resistance, stalling, indecision.',
        revEs: 'Demoras, resistencia, indecisión.',
        revPt: 'Atrasos, resistência, indecisão.',
        revRu: 'Задержки, сопротивление, нерешительность.',
        loveEn: 'Step back and see your relationship from a new angle. Patience reveals deeper truths.',
        workEn: 'A temporary pause allows for valuable insight. Don\'t force progress — allow it.',
        healthEn: 'Rest and surrender to the healing process. Fighting resistance only delays recovery.'),
    _major(13, 'Death', 'La Muerte', 'A Morte', 'Смерть',
        upEn: 'Endings, change, transformation, transition. One door closes so another can open.',
        upEs: 'Finales, cambio, transformación. Una puerta se cierra para que otra se abra.',
        upPt: 'Finais, mudança, transformação. Uma porta se fecha para outra abrir.',
        upRu: 'Окончания, перемены, трансформация. Одна дверь закрывается, чтобы открылась другая.',
        revEn: 'Resistance to change, personal transformation, inner purging.',
        revEs: 'Resistencia al cambio, transformación personal.',
        revPt: 'Resistência à mudança, transformação pessoal.',
        revRu: 'Сопротивление переменам, внутренняя трансформация.',
        loveEn: 'A significant relationship transformation is underway. Embrace the change — it leads to deeper connection.',
        workEn: 'An old chapter in your career is ending, making room for exciting new beginnings.',
        healthEn: 'Release old habits that no longer serve you. Transformation supports renewed vitality.'),
    _major(14, 'Temperance', 'La Templanza', 'A Temperança', 'Умеренность',
        upEn: 'Balance, moderation, patience, purpose, meaning. Find the middle path.',
        upEs: 'Equilibrio, moderación, paciencia. Encuentra el camino del medio.',
        upPt: 'Equilíbrio, moderação, paciência. Encontre o caminho do meio.',
        upRu: 'Баланс, умеренность, терпение. Найдите срединный путь.',
        revEn: 'Imbalance, excess, lack of long-term vision.',
        revEs: 'Desequilibrio, exceso, falta de visión a largo plazo.',
        revPt: 'Desequilíbrio, excesso, falta de visão a longo prazo.',
        revRu: 'Дисбаланс, излишества, отсутствие долгосрочного видения.',
        loveEn: 'Balance and patience create lasting harmony. Avoid extremes — seek the middle ground.',
        workEn: 'A balanced, patient approach to your career goals produces sustainable results.',
        healthEn: 'Moderation in all things supports lasting health. Blend activity with proper rest.'),
    _major(15, 'The Devil', 'El Diablo', 'O Diabo', 'Дьявол',
        upEn: 'Shadow self, attachment, addiction, restriction, sexuality. Face what binds you.',
        upEs: 'Sombra, apego, adicción, restricción. Enfrenta lo que te ata.',
        upPt: 'Sombra, apego, vício, restrição. Enfrente o que o prende.',
        upRu: 'Тень, привязанность, зависимость, ограничение. Встретьтесь с тем, что вас сковывает.',
        revEn: 'Releasing limiting beliefs, exploring dark thoughts, detachment.',
        revEs: 'Liberación de creencias limitantes, explorar pensamientos oscuros.',
        revPt: 'Liberação de crenças limitantes, explorar pensamentos sombrios.',
        revRu: 'Освобождение от ограничивающих убеждений, отстранение.',
        loveEn: 'Examine unhealthy patterns in your relationship. True freedom comes from honest self-awareness.',
        workEn: 'Break free from limiting work patterns or toxic dynamics. You have more power than you realize.',
        healthEn: 'Identify and address unhealthy habits. Awareness is the first step to freedom.'),
    _major(16, 'The Tower', 'La Torre', 'A Torre', 'Башня',
        upEn: 'Sudden change, upheaval, chaos, revelation, awakening. Necessary destruction clears the path.',
        upEs: 'Cambio repentino, caos, revelación. La destrucción necesaria despeja el camino.',
        upPt: 'Mudança súbita, caos, revelação. A destruição necessária limpa o caminho.',
        upRu: 'Внезапные перемены, хаос, откровение. Необходимое разрушение расчищает путь.',
        revEn: 'Personal transformation, fear of change, averting disaster.',
        revEs: 'Transformación personal, miedo al cambio, evitar el desastre.',
        revPt: 'Transformação pessoal, medo de mudança, evitar desastre.',
        revRu: 'Личная трансформация, страх перемен.',
        loveEn: 'A sudden shift shakes your relationship\'s foundations. Trust that what remains is worth keeping.',
        workEn: 'Unexpected disruption at work leads to necessary and ultimately positive change.',
        healthEn: 'A health wake-up call prompts necessary change. Act on what you\'ve been avoiding.'),
    _major(17, 'The Star', 'La Estrella', 'A Estrela', 'Звезда',
        upEn: 'Hope, faith, purpose, renewal, spirituality. You are guided and protected.',
        upEs: 'Esperanza, fe, propósito, renovación. Estás guiado y protegido.',
        upPt: 'Esperança, fé, propósito, renovação. Você está guiado e protegido.',
        upRu: 'Надежда, вера, цель, обновление. Вы направляемы и защищены.',
        revEn: 'Lack of faith, despair, self-trust, disconnection.',
        revEs: 'Falta de fe, desesperación, falta de confianza en uno mismo.',
        revPt: 'Falta de fé, desespero, falta de autoconfiança.',
        revRu: 'Отсутствие веры, отчаяние, недоверие к себе.',
        loveEn: 'Hope and healing flow into your love life. A bright and nourishing connection is forming.',
        workEn: 'Your professional path is guided by purpose. Trust the process — better things are coming.',
        healthEn: 'Healing energy surrounds you. Hope and self-care light the way to restored vitality.'),
    _major(18, 'The Moon', 'La Luna', 'A Lua', 'Луна',
        upEn: 'Illusion, fear, the unconscious, intuition, confusion. Look beneath the surface.',
        upEs: 'Ilusión, miedo, el inconsciente, intuición. Mira más allá de las apariencias.',
        upPt: 'Ilusão, medo, o inconsciente, intuição. Olhe além das aparências.',
        upRu: 'Иллюзия, страх, подсознание, интуиция. Загляните за поверхность.',
        revEn: 'Release of fear, repressed emotion, inner confusion.',
        revEs: 'Liberación del miedo, emoción reprimida, confusión interior.',
        revPt: 'Liberação do medo, emoção reprimida, confusão interior.',
        revRu: 'Освобождение от страха, подавленные эмоции, внутреннее смятение.',
        loveEn: 'Not all is as it appears in your love life. Trust your instincts over what seems obvious.',
        workEn: 'Unclear situations at work require intuitive navigation. Wait for greater clarity.',
        healthEn: 'Emotional and psychological wellbeing needs attention. Trust your body\'s signals.'),
    _major(19, 'The Sun', 'El Sol', 'O Sol', 'Солнце',
        upEn: 'Positivity, fun, warmth, success, vitality. A radiant period of joy and achievement.',
        upEs: 'Positividad, diversión, calidez, éxito. Un período radiante de alegría y logro.',
        upPt: 'Positividade, diversão, calor, sucesso. Um período radiante de alegria e conquista.',
        upRu: 'Позитивность, радость, тепло, успех. Лучезарный период счастья и достижений.',
        revEn: 'Inner child, feeling down, overly optimistic.',
        revEs: 'Niño interior, sentirse decaído, excesivamente optimista.',
        revPt: 'Criança interior, sentindo-se para baixo, excessivamente otimista.',
        revRu: 'Внутренний ребёнок, подавленность, чрезмерный оптимизм.',
        loveEn: 'Warmth and joy illuminate your love life. This is a time of happiness and genuine connection.',
        workEn: 'Success and recognition shine on your professional endeavors. Your efforts are bearing fruit.',
        healthEn: 'Vibrant energy and vitality support excellent health. Enjoy and nurture this positive phase.'),
    _major(20, 'Judgement', 'El Juicio', 'O Julgamento', 'Суд',
        upEn: 'Judgement, rebirth, inner calling, absolution. Answer the call to a higher purpose.',
        upEs: 'Juicio, renacimiento, llamada interior. Responde al llamado de un propósito superior.',
        upPt: 'Julgamento, renascimento, chamada interior. Responda ao chamado de um propósito superior.',
        upRu: 'Суд, возрождение, внутренний зов. Ответьте на зов высшей цели.',
        revEn: 'Self-doubt, inner critic, ignoring the call.',
        revEs: 'Autoduda, crítico interior, ignorar el llamado.',
        revPt: 'Autodúvida, crítico interior, ignorar o chamado.',
        revRu: 'Сомнения в себе, внутренний критик, игнорирование зова.',
        loveEn: 'A meaningful evaluation of your love life leads to a significant awakening and renewal.',
        workEn: 'A career awakening calls you toward work that truly aligns with your deeper purpose.',
        healthEn: 'A health transformation is calling. Heed the signs and commit to meaningful change.'),
    _major(21, 'The World', 'El Mundo', 'O Mundo', 'Мир',
        upEn: 'Completion, integration, accomplishment, travel. You have reached a beautiful milestone.',
        upEs: 'Finalización, integración, logro. Has alcanzado un hermoso hito.',
        upPt: 'Conclusão, integração, conquista. Você alcançou um belo marco.',
        upRu: 'Завершение, интеграция, достижение. Вы достигли прекрасного рубежа.',
        revEn: 'Seeking personal closure, short-cuts, delays.',
        revEs: 'Buscando cierre personal, atajos, demoras.',
        revPt: 'Buscando fechamento pessoal, atalhos, atrasos.',
        revRu: 'Поиск личного завершения, срезание углов, задержки.',
        loveEn: 'A fulfilling and complete chapter in your love story. Celebrate how far you\'ve come together.',
        workEn: 'A major professional milestone reached. Your work is recognized and celebrated.',
        healthEn: 'A sense of wholeness and completion in your health journey. You are thriving.'),
  ];

  // ─── Minor Arcana builder (22–77) ──────────────────────────────────────────

  static List<TarotCard> _buildMinorArcana() {
    final cards = <TarotCard>[];
    const suits = [TarotSuit.cups, TarotSuit.wands, TarotSuit.swords, TarotSuit.pentacles];
    const suitNamesEn = ['Cups', 'Wands', 'Swords', 'Pentacles'];
    const suitNamesEs = ['Copas', 'Bastos', 'Espadas', 'Pentáculos'];
    const suitNamesPt = ['Copas', 'Paus', 'Espadas', 'Pentáculos'];
    const suitNamesRu = ['Кубков', 'Жезлов', 'Мечей', 'Пентаклей'];

    for (var s = 0; s < suits.length; s++) {
      final suit = suits[s];
      final suitEn = suitNamesEn[s];
      final suitEs = suitNamesEs[s];
      final suitPt = suitNamesPt[s];
      final suitRu = suitNamesRu[s];
      final suitTheme = _suitTheme(suit);

      for (var r = 1; r <= 14; r++) {
        final cardIndex = 22 + (s * 14) + (r - 1);
        final rankEn = _rankNameEn(r);
        final rankEs = _rankNameEs(r);
        final rankPt = _rankNamePt(r);
        final rankRu = _rankNameRu(r);

        final nameEn = '$rankEn of $suitEn';
        final nameEs = '$rankEs de $suitEs';
        final namePt = '$rankPt de $suitPt';
        final nameRu = '$rankRu $suitRu';

        final upright = _minorMeaning(suit, r, reversed: false);
        final reversed = _minorMeaning(suit, r, reversed: true);
        final love = _minorContext(suit, r, 'love');
        final work = _minorContext(suit, r, 'work');
        final health = _minorContext(suit, r, 'health');

        cards.add(TarotCard(
          id: 'minor_${suit.name}_$r',
          number: cardIndex,
          arcana: TarotArcana.minor,
          suit: suit,
          names: LocalizedText(en: nameEn, es: nameEs, pt: namePt, ru: nameRu),
          imageUrl: '',
          imageLicense: 'pending',
          imageSource: 'pending',
          meanings: TarotMeanings(
            upright: LocalizedText(en: upright, es: upright, pt: upright, ru: upright),
            reversed: LocalizedText(en: reversed, es: reversed, pt: reversed, ru: reversed),
            love: LocalizedText(en: love, es: love, pt: love, ru: love),
            work: LocalizedText(en: work, es: work, pt: work, ru: work),
            health: LocalizedText(en: health, es: health, pt: health, ru: health),
          ),
          version: 0,
        ));
      }
    }
    return cards;
  }

  // ─── Minor Arcana meaning generators ────────────────────────────────────────

  static String _suitTheme(TarotSuit suit) => switch (suit) {
    TarotSuit.cups => 'emotions, relationships, and intuition',
    TarotSuit.wands => 'passion, creativity, and ambition',
    TarotSuit.swords => 'thought, conflict, and communication',
    TarotSuit.pentacles => 'material world, work, and abundance',
    _ => 'the unseen forces',
  };

  static String _minorMeaning(TarotSuit suit, int rank, {required bool reversed}) {
    final theme = _suitTheme(suit);
    final rankLabel = _rankNameEn(rank).toLowerCase();
    if (!reversed) {
      return 'The $rankLabel of ${suit.name} speaks to $theme. '
          'Energy flows forward with clarity and purpose. '
          'For entertainment purposes only.';
    } else {
      return 'The $rankLabel of ${suit.name} reversed suggests blocked energy '
          'around $theme. Reflection and inner work are called for. '
          'For entertainment purposes only.';
    }
  }

  static String _minorContext(TarotSuit suit, int rank, String context) {
    final theme = _suitTheme(suit);
    return switch (context) {
      'love' => 'In love, the energy of $theme brings ${_contextWord(suit, rank, "love")}. '
          'For entertainment purposes only.',
      'work' => 'At work, the energy of $theme suggests ${_contextWord(suit, rank, "work")}. '
          'For entertainment purposes only.',
      _ => 'For your wellbeing, the energy of $theme encourages ${_contextWord(suit, rank, "health")}. '
          'For entertainment purposes only.',
    };
  }

  static String _contextWord(TarotSuit suit, int rank, String context) {
    // Higher rank = more developed energy
    final intensity = rank <= 5 ? 'emerging' : rank <= 10 ? 'active' : 'mature';
    return switch (suit) {
      TarotSuit.cups => switch (context) {
          'love' => '$intensity emotional connection and heartfelt communication',
          'work' => '$intensity creative collaboration and emotional intelligence',
          _ => '$intensity emotional balance and inner peace',
        },
      TarotSuit.wands => switch (context) {
          'love' => '$intensity passion and spark of adventure',
          'work' => '$intensity drive, ambition, and creative initiative',
          _ => '$intensity vitality and enthusiasm for life',
        },
      TarotSuit.swords => switch (context) {
          'love' => '$intensity clarity and honest, direct communication',
          'work' => '$intensity strategic thinking and decisive action',
          _ => '$intensity mental clarity and stress management',
        },
      TarotSuit.pentacles => switch (context) {
          'love' => '$intensity security, loyalty, and practical support',
          'work' => '$intensity focus on material goals and financial stability',
          _ => '$intensity attention to physical health and daily routines',
        },
      _ => '$intensity energy',
    };
  }

  // ─── Rank name helpers ─────────────────────────────────────────────────────

  static String _rankNameEn(int r) => switch (r) {
    1 => 'Ace', 11 => 'Page', 12 => 'Knight', 13 => 'Queen', 14 => 'King',
    _ => r.toString(),
  };

  static String _rankNameEs(int r) => switch (r) {
    1 => 'As', 11 => 'Sota', 12 => 'Caballo', 13 => 'Reina', 14 => 'Rey',
    _ => r.toString(),
  };

  static String _rankNamePt(int r) => switch (r) {
    1 => 'Ás', 11 => 'Valete', 12 => 'Cavaleiro', 13 => 'Rainha', 14 => 'Rei',
    _ => r.toString(),
  };

  static String _rankNameRu(int r) => switch (r) {
    1 => 'Туз', 11 => 'Паж', 12 => 'Рыцарь', 13 => 'Королева', 14 => 'Король',
    _ => '$r',
  };

  // ─── Major Arcana factory ──────────────────────────────────────────────────

  static TarotCard _major(
    int number,
    String nameEn,
    String nameEs,
    String namePt,
    String nameRu, {
    required String upEn,
    required String upEs,
    required String upPt,
    required String upRu,
    required String revEn,
    required String revEs,
    required String revPt,
    required String revRu,
    required String loveEn,
    required String workEn,
    required String healthEn,
  }) {
    return TarotCard(
      id: 'major_${number.toString().padLeft(2, '0')}_${nameEn.toLowerCase().replaceAll(' ', '_').replaceAll('the_', '')}',
      number: number,
      arcana: TarotArcana.major,
      suit: TarotSuit.none,
      names: LocalizedText(en: nameEn, es: nameEs, pt: namePt, ru: nameRu),
      imageUrl: 'assets/images/tarot/tarot_major_$number.png',
      imageLicense: 'proprietary',
      imageSource: 'AstraLume original artwork',
      meanings: TarotMeanings(
        upright: LocalizedText(en: upEn, es: upEs, pt: upPt, ru: upRu),
        reversed: LocalizedText(en: revEn, es: revEs, pt: revPt, ru: revRu),
        love: LocalizedText(en: loveEn, es: loveEn, pt: loveEn, ru: loveEn),
        work: LocalizedText(en: workEn, es: workEn, pt: workEn, ru: workEn),
        health: LocalizedText(en: healthEn, es: healthEn, pt: healthEn, ru: healthEn),
      ),
      version: 1,
    );
  }
}
