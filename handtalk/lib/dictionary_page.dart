/// HandTalk - Kamus & Pembelajaran BISINDO
/// Halaman interaktif untuk belajar isyarat BISINDO
/// Fitur: Kamus A-Z, Kategori, Detail isyarat, Quiz mode

import 'package:flutter/material.dart';
import 'core/themes.dart';
import 'services/camera/bisindo_alphabet_data.dart';
import 'services/auth_service.dart';
import 'widgets/animated_hand_gesture.dart';

class DictionaryPage extends StatefulWidget {
  final UserModel user;

  const DictionaryPage({super.key, required this.user});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Quiz state
  bool _quizMode = false;
  int _quizScore = 0;
  int _quizTotal = 0;
  String? _quizCurrentLetter;
  List<String> _quizOptions = [];
  bool? _quizAnswered;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kamus BISINDO'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_quizMode ? Icons.book : Icons.quiz),
            tooltip: _quizMode ? 'Mode Kamus' : 'Mode Quiz',
            onPressed: _toggleQuizMode,
          ),
        ],
        bottom: _quizMode
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Alfabet', icon: Icon(Icons.abc, size: 20)),
                  Tab(
                      text: 'Kategori',
                      icon: Icon(Icons.category, size: 20)),
                ],
              ),
      ),
      body: _quizMode ? _buildQuizView() : _buildDictionaryView(),
    );
  }

  // ─── Dictionary View ──────────────────────────────────────────────────────

  Widget _buildDictionaryView() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari isyarat...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAlphabetGrid(),
              _buildCategoryList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlphabetGrid() {
    final allGestures = BisindoAlphabetData.allAlphabets;
    final filtered = _searchQuery.isEmpty
        ? allGestures
        : allGestures
            .where((g) =>
                g.letter.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                g.description
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('Tidak ditemukan',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final gesture = filtered[index];
        return _buildAlphabetCard(gesture);
      },
    );
  }

  Widget _buildAlphabetCard(BisindoGesture gesture) {
    final handLabel = gesture.handType == HandType.twoHand ? '2 tangan' : '1 tangan';
    return Semantics(
      button: true,
      label: 'Huruf ${gesture.letter}, $handLabel. Ketuk untuk detail',
      child: GestureDetector(
        onTap: () => _showGestureDetail(gesture),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Text(
                  gesture.letter,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: Text(
                  handLabel,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    final categories = [
      _CategoryItem('Salam & Sapaan', Icons.waving_hand, [
        'Halo',
        'Selamat Pagi',
        'Terima Kasih',
        'Maaf',
        'Permisi'
      ], color: const Color(0xFFFF7043), emoji: '👋'),
      _CategoryItem(
          'Keluarga', Icons.family_restroom, ['Ayah', 'Ibu', 'Kakak', 'Adik', 'Keluarga'],
          color: const Color(0xFF5C6BC0), emoji: '👨‍👩‍👧‍👦'),
      _CategoryItem(
          'Perasaan', Icons.emoji_emotions, ['Senang', 'Sedih', 'Marah', 'Takut', 'Cinta'],
          color: const Color(0xFF26A69A), emoji: '😊'),
      _CategoryItem(
          'Aktivitas', Icons.directions_run, ['Makan', 'Minum', 'Tidur', 'Belajar', 'Bermain'],
          color: const Color(0xFFEF5350), emoji: '🏃'),
      _CategoryItem('Tempat', Icons.place, ['Rumah', 'Sekolah', 'Kantor', 'Rumah Sakit', 'Toko'],
          color: const Color(0xFF66BB6A), emoji: '🏠'),
      _CategoryItem('Waktu', Icons.access_time, ['Hari', 'Minggu', 'Bulan', 'Sekarang', 'Nanti'],
          color: const Color(0xFFAB47BC), emoji: '⏰'),
      _CategoryItem(
          'Pertanyaan', Icons.help_outline, ['Apa', 'Siapa', 'Dimana', 'Kapan', 'Mengapa'],
          color: const Color(0xFF42A5F5), emoji: '❓'),
      _CategoryItem(
          'Darurat', Icons.warning_amber, ['Tolong', 'Bahaya', 'Sakit', 'Polisi', 'Ambulans'],
          color: const Color(0xFFFF8A65), emoji: '🚨'),
    ];

    final filtered = _searchQuery.isEmpty
        ? categories
        : categories
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.words.any((w) =>
                    w.toLowerCase().contains(_searchQuery.toLowerCase())))
            .toList();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final category = filtered[index];
        return _buildCategoryGridCard(category);
      },
    );
  }

  Widget _buildCategoryGridCard(_CategoryItem category) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToCategoryDetail(category),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                category.color.withOpacity(0.05),
                category.color.withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: category.color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: category.color.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon/Logo area - larger with icon + emoji combo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: category.color.withOpacity(0.3)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      category.icon,
                      color: category.color,
                      size: 30,
                    ),
                    // Small emoji badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Category name
              Text(
                category.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: category.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // Word count with icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sign_language, size: 10, color: category.color.withOpacity(0.6)),
                  const SizedBox(width: 3),
                  Text(
                    '${category.words.length} isyarat',
                    style: TextStyle(
                      fontSize: 10,
                      color: category.color.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCategoryDetail(_CategoryItem category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CategoryDetailPage(category: category),
      ),
    );
  }

  // ─── Gesture Detail Dialog ────────────────────────────────────────────────

  void _showGestureDetail(BisindoGesture gesture) {
    final imagePath = 'assets/images/gestures/alphabet_${gesture.letter.toLowerCase()}.png';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Gesture image
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to animated gesture
                        return AnimatedHandGesture(
                          gesture: gesture,
                          size: 160,
                          autoPlay: true,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Video tutorial section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.play_circle_filled, color: AppColors.info, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Video Tutorial',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.info,
                              ),
                            ),
                            Text(
                              'Lihat video gerakan huruf ${gesture.letter}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.info),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info chips
                Center(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          gesture.handType == HandType.twoHand
                              ? 'Dua Tangan'
                              : 'Satu Tangan',
                          style: const TextStyle(fontSize: 12),
                        ),
                        avatar: const Icon(Icons.pan_tool, size: 16),
                      ),
                      if (gesture.hasMotion)
                        const Chip(
                          label: Text('Ada Gerakan',
                              style: TextStyle(fontSize: 12)),
                          avatar: Icon(Icons.motion_photos_on, size: 16),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                const Text('Deskripsi',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(gesture.description,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 16),

                // Instruction
                const Text('Cara Melakukan',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          gesture.instruction,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Finger pattern info
                const Text('Pola Jari',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildFingerPatternVisual(gesture.fingerPattern),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFingerPatternVisual(FingerPattern pattern) {
    final fingers = [
      ('Jempol', pattern.thumb),
      ('Telunjuk', pattern.index),
      ('Tengah', pattern.middle),
      ('Manis', pattern.ring),
      ('Kelingking', pattern.pinky),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.textHint.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: fingers.map((f) {
          final isExtended = f.$2;
          return Column(
            children: [
              Icon(
                isExtended ? Icons.arrow_upward : Icons.arrow_downward,
                color: isExtended ? AppColors.success : AppColors.textHint,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                f.$1,
                style: TextStyle(
                  fontSize: 10,
                  color: isExtended ? AppColors.success : AppColors.textHint,
                  fontWeight:
                      isExtended ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showWordDetail(String word) {
    // Determine image path for the word
    final wordSlug = word.toLowerCase().replaceAll(' ', '_');
    final imagePath = 'assets/images/gestures/word_$wordSlug.png';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sign_language, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(word, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gesture image
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sign_language,
                              size: 40, color: AppColors.primary),
                          const SizedBox(height: 8),
                          Text(
                            'Isyarat: $word',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '(Gambar akan segera tersedia)',
                            style: TextStyle(fontSize: 10, color: AppColors.textHint),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Video reference placeholder
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_filled, color: AppColors.info, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Video Tutorial',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                          Text(
                            'Lihat video gerakan isyarat "$word"',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.info, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Instruction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Cara Melakukan:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lakukan isyarat "$word" sesuai panduan BISINDO.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Tip
              Row(
                children: [
                  const Icon(Icons.tips_and_updates, size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Gunakan tab Kamera di halaman Terjemah untuk berlatih!',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ─── Quiz Mode ────────────────────────────────────────────────────────────

  void _toggleQuizMode() {
    setState(() {
      _quizMode = !_quizMode;
      if (_quizMode) {
        _quizScore = 0;
        _quizTotal = 0;
        _generateQuizQuestion();
      }
    });
  }

  void _generateQuizQuestion() {
    final allGestures = BisindoAlphabetData.allAlphabets;
    allGestures.shuffle();

    _quizCurrentLetter = allGestures.first.letter;
    _quizAnswered = null;

    // Generate 4 options (1 correct + 3 wrong)
    final options = <String>[_quizCurrentLetter!];
    final others = allGestures
        .where((g) => g.letter != _quizCurrentLetter)
        .map((g) => g.letter)
        .toList();
    others.shuffle();
    options.addAll(others.take(3));
    options.shuffle();

    setState(() => _quizOptions = options);
  }

  void _answerQuiz(String answer) {
    if (_quizAnswered != null) return;

    setState(() {
      _quizAnswered = answer == _quizCurrentLetter;
      _quizTotal++;
      if (_quizAnswered!) _quizScore++;
    });

    // Auto next after 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _quizMode) {
        _generateQuizQuestion();
      }
    });
  }

  Widget _buildQuizView() {
    if (_quizCurrentLetter == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final gesture = BisindoAlphabetData.getByLetter(_quizCurrentLetter!);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Skor: $_quizScore / $_quizTotal',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _toggleQuizMode,
                icon: const Icon(Icons.close),
                label: const Text('Keluar Quiz'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Question
          const Text(
            'Isyarat apa ini?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // Gesture description as clue
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.sign_language,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  gesture?.instruction ?? 'Lakukan isyarat ini',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                if (gesture != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    gesture.handType == HandType.twoHand
                        ? 'Menggunakan dua tangan'
                        : 'Menggunakan satu tangan',
                    style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textHint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Options
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: _quizOptions.map((option) {
                Color bgColor = AppColors.surface;
                Color borderColor = AppColors.textHint.withOpacity(0.3);
                Color textColor = AppColors.textPrimary;

                if (_quizAnswered != null) {
                  if (option == _quizCurrentLetter) {
                    bgColor = AppColors.success.withOpacity(0.15);
                    borderColor = AppColors.success;
                    textColor = AppColors.success;
                  } else if (option != _quizCurrentLetter &&
                      _quizAnswered == false) {
                    bgColor = AppColors.error.withOpacity(0.08);
                    borderColor = AppColors.error.withOpacity(0.3);
                  }
                }

                return GestureDetector(
                  onTap: () => _answerQuiz(option),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Feedback
          if (_quizAnswered != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _quizAnswered!
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _quizAnswered! ? Icons.check_circle : Icons.cancel,
                    color:
                        _quizAnswered! ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _quizAnswered! ? 'Benar!' : 'Salah! Jawaban: $_quizCurrentLetter',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _quizAnswered!
                          ? AppColors.success
                          : AppColors.error,
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

// ─── Helper Classes ─────────────────────────────────────────────────────────

class _CategoryItem {
  final String name;
  final IconData icon;
  final List<String> words;
  final Color color;
  final String emoji;

  _CategoryItem(this.name, this.icon, this.words, {
    this.color = AppColors.primary,
    this.emoji = '📚',
  });
}

// ─── Category Detail Page ───────────────────────────────────────────────────

class _CategoryDetailPage extends StatelessWidget {
  final _CategoryItem category;

  const _CategoryDetailPage({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Category header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.08),
              border: Border(
                bottom: BorderSide(color: category.color.withOpacity(0.2)),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: category.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${category.words.length} kata isyarat',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Word list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: category.words.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final word = category.words[index];
                return _buildWordCard(context, word, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(BuildContext context, String word, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showWordDetailDialog(context, word),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: category.color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Number badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: category.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Word info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ketuk untuk melihat isyarat',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              // Sign language icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.sign_language,
                  color: category.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWordDetailDialog(BuildContext context, String word) {
    // Determine image path based on category and word
    final imageName = word.toLowerCase().replaceAll(' ', '_');
    final categoryPrefix = category.name.toLowerCase().split(' ').first;
    final imagePath = 'assets/images/gestures/${categoryPrefix}_$imageName.png';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sign_language, color: category.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                word,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gesture image
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: category.color.withOpacity(0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sign_language, size: 48, color: category.color),
                          const SizedBox(height: 8),
                          Text(
                            'Isyarat: $word',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: category.color,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(Gambar akan segera tersedia)',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Instruction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Cara Melakukan:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lakukan isyarat "$word" sesuai panduan BISINDO.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Tip
              Row(
                children: [
                  const Icon(Icons.tips_and_updates, size: 14, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Gunakan tab Kamera di halaman Terjemah untuk berlatih!',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
