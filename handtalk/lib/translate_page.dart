/// HandTalk - Translation Page
/// Pattern: StatefulWidget + setState(), imperative navigation, SnackBar feedback
/// Two tabs: "Teks ke Isyarat" (text→sign) and "Kamera BISINDO" (camera detection)

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:uuid/uuid.dart';

import 'core/themes.dart';
import 'core/constants.dart';
import 'services/auth_service.dart';
import 'services/translation_service.dart';
import 'services/feedback_service.dart';
import 'services/audio_service.dart';
import 'services/camera/camera_service.dart';
import 'services/camera/gesture_recognizer.dart';
import 'services/camera/bisindo_alphabet_data.dart';

class TranslatePage extends StatefulWidget {
  final UserModel user;

  const TranslatePage({super.key, required this.user});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage>
    with SingleTickerProviderStateMixin {
  // ─── Tab Controller ─────────────────────────────────────────────────────────
  late TabController _tabController;

  // ─── Text Translation State ─────────────────────────────────────────────────
  final _textController = TextEditingController();
  bool _isTranslating = false;
  TranslationResult? _translationResult;
  int? _savedTranslationId;
  String _sessionId = const Uuid().v4();

  // ─── Camera State ───────────────────────────────────────────────────────────
  final CameraService _cameraService = CameraService();
  GestureRecognizer? _gestureRecognizer;
  bool _cameraInitialized = false;
  bool _cameraInitializing = false;
  bool _isDetecting = false;
  GestureResult? _lastGestureResult;
  String _builtSentence = '';
  bool _cameraPermissionDenied = false;

  // ─── Quick Word Chips ───────────────────────────────────────────────────────
  final List<String> _quickWords = [
    'Halo',
    'Terima Kasih',
    'Maaf',
    'Tolong',
    'Makan',
    'Minum',
    'Senang',
    'Rumah',
  ];

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    AudioService().init();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _textController.dispose();
    _disposeCamera();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_cameraInitialized && !_cameraInitializing) {
      _initializeCamera();
    }
  }

  // ─── Camera Initialization ────────────────────────────────────────────────

  Future<void> _initializeCamera() async {
    if (_cameraInitializing) return;
    setState(() => _cameraInitializing = true);

    try {
      await _cameraService.initialize();
      final started = await _cameraService.startCamera();

      if (!mounted) return;

      if (!started) {
        setState(() {
          _cameraPermissionDenied = true;
          _cameraInitializing = false;
        });
        return;
      }

      _gestureRecognizer = GestureRecognizer();

      // Initialize AI model (TFLite) for better recognition
      final aiReady = await _gestureRecognizer!.initializeAI();
      debugPrint('[TranslatePage] AI model ready: $aiReady');

      setState(() {
        _cameraInitialized = true;
        _cameraInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraPermissionDenied = true;
        _cameraInitializing = false;
      });
      _showSnackBar('Gagal mengakses kamera', isError: true);
    }
  }

  Future<void> _disposeCamera() async {
    await _stopDetection();
    await _gestureRecognizer?.dispose();
    await _cameraService.dispose();
  }

  // ─── Camera Detection ─────────────────────────────────────────────────────

  Future<void> _startDetection() async {
    if (!_cameraInitialized || _isDetecting) return;

    setState(() => _isDetecting = true);

    try {
      await _cameraService.startImageStream((CameraImage image) async {
        if (!_isDetecting || _gestureRecognizer == null) return;
        if (_cameraService.controller == null) return;

        final camera = _cameraService.controller!.description;
        final result = await _gestureRecognizer!.processFrame(image, camera);

        if (!mounted) return;

        if (result.detectedLetter != null || result.handsDetected) {
          setState(() => _lastGestureResult = result);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDetecting = false);
      _showSnackBar('Gagal memulai deteksi', isError: true);
    }
  }

  Future<void> _stopDetection() async {
    setState(() => _isDetecting = false);
    await _cameraService.stopImageStream();
    _gestureRecognizer?.reset();
  }

  /// Switch between front and back camera
  Future<void> _switchCamera() async {
    // Stop detection if running
    final wasDetecting = _isDetecting;
    if (_isDetecting) {
      await _stopDetection();
    }

    setState(() => _cameraInitializing = true);

    try {
      await _cameraService.switchCamera();

      if (!mounted) return;
      setState(() {
        _cameraInitializing = false;
      });

      // Resume detection if it was running
      if (wasDetecting) {
        await _startDetection();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraInitializing = false);
      _showSnackBar('Gagal mengganti kamera', isError: true);
    }
  }

  // ─── Text Translation Handler ─────────────────────────────────────────────

  Future<void> _handleTranslate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Masukkan teks untuk diterjemahkan', isError: true);
      return;
    }

    setState(() {
      _isTranslating = true;
      _translationResult = null;
      _savedTranslationId = null;
    });

    try {
      final translationService = TranslationService();
      final result = await translationService.translateTextToSign(text);

      if (!mounted) return;

      // Save translation to database
      final charCount = text.length;
      final wordCount = text.split(RegExp(r'\s+')).length;
      final translationId = await translationService.saveTranslation(
        text,
        result.translatedText,
        'text_to_sign',
        charCount,
        wordCount,
      );

      // Save history
      final userId = widget.user.id ?? 0;
      await translationService.saveHistory(userId, translationId, _sessionId);

      if (!mounted) return;

      setState(() {
        _translationResult = result;
        _savedTranslationId = translationId;
        _isTranslating = false;
      });

      _showSnackBar('Terjemahan berhasil!', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTranslating = false);
      _showSnackBar('Gagal menerjemahkan teks', isError: true);
    }
  }

  // ─── Feedback Handler ─────────────────────────────────────────────────────

  Future<void> _handleFeedback(bool isCorrect) async {
    if (_savedTranslationId == null) return;

    final comment = await _showFeedbackDialog(isCorrect);
    if (comment == null) return; // User cancelled

    try {
      final feedbackService = FeedbackService();
      await feedbackService.submitFeedback(
        widget.user.id ?? 0,
        _savedTranslationId!,
        isCorrect,
        comment,
      );

      if (!mounted) return;
      _showSnackBar(
        isCorrect ? 'Terima kasih atas konfirmasi!' : 'Feedback dikirim, terima kasih!',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal mengirim feedback', isError: true);
    }
  }

  Future<String?> _showFeedbackDialog(bool isCorrect) async {
    final commentController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            isCorrect ? 'Konfirmasi Benar' : 'Laporkan Kesalahan',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCorrect
                    ? 'Apakah terjemahan ini sudah benar?'
                    : 'Apa yang salah dari terjemahan ini?',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Komentar (opsional)...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, commentController.text),
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );
  }

  // ─── Audio Handler ────────────────────────────────────────────────────────

  Future<void> _handleSpeak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await AudioService().speak(text);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal memutar audio', isError: true);
    }
  }

  // ─── Camera Sentence Builder ──────────────────────────────────────────────

  void _addLetterToSentence(String letter) {
    setState(() {
      _builtSentence += letter;
    });
  }

  void _addSpaceToSentence() {
    setState(() {
      _builtSentence += ' ';
    });
  }

  void _backspaceSentence() {
    if (_builtSentence.isNotEmpty) {
      setState(() {
        _builtSentence = _builtSentence.substring(0, _builtSentence.length - 1);
      });
    }
  }

  void _clearSentence() {
    setState(() {
      _builtSentence = '';
      _lastGestureResult = null;
    });
  }

  Future<void> _translateBuiltSentence() async {
    if (_builtSentence.trim().isEmpty) {
      _showSnackBar('Belum ada teks untuk diterjemahkan', isError: true);
      return;
    }

    _textController.text = _builtSentence.trim();
    _tabController.animateTo(0);

    // Small delay to let tab switch complete
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _handleTranslate();
  }

  // ─── SnackBar Helper ──────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terjemahan BISINDO'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields, size: 20), text: 'Teks ke Isyarat'),
            Tab(icon: Icon(Icons.camera_alt, size: 20), text: 'Kamera BISINDO'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildTextToSignTab(),
          _buildCameraTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: TEXT TO SIGN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTextToSignTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextInput(),
          const SizedBox(height: 12),
          _buildQuickWordChips(),
          const SizedBox(height: 16),
          _buildTranslateButton(),
          const SizedBox(height: 16),
          if (_isTranslating) _buildLoadingIndicator(),
          if (_translationResult != null) ...[
            _buildResultCard(),
            const SizedBox(height: 12),
            _buildMatchedGesturesList(),
            const SizedBox(height: 12),
            _buildFeedbackButtons(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return TextField(
      controller: _textController,
      maxLines: 3,
      minLines: 2,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        hintText: 'Ketik teks yang ingin diterjemahkan ke BISINDO...',
        prefixIcon: Icon(Icons.edit_note, color: AppColors.primary),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildQuickWordChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kata Cepat:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickWords.map((word) {
            return ActionChip(
              label: Text(
                word,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () {
                _textController.text = word;
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: word.length),
                );
              },
              backgroundColor: AppColors.primaryLight.withOpacity(0.15),
              side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
              avatar: const Icon(Icons.touch_app, size: 14, color: AppColors.primary),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTranslateButton() {
    return Semantics(
      button: true,
      label: 'Terjemahkan teks ke bahasa isyarat BISINDO',
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isTranslating ? null : _handleTranslate,
          icon: const Icon(Icons.translate, size: 20,
              semanticLabel: 'Terjemahkan'),
          label: const Text('Terjemahkan ke BISINDO'),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Menerjemahkan...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _translationResult!;
    final sourceText = result.sourceText;
    final charCount = sourceText.length;
    final wordCount = sourceText.split(RegExp(r'\s+')).length;
    final confidencePercent = (result.confidence * 100).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Hasil Terjemahan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Speak button
              IconButton(
                onPressed: () => _handleSpeak(result.sourceText),
                icon: const Icon(Icons.volume_up, size: 20),
                color: AppColors.primary,
                tooltip: 'Dengarkan',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const Divider(height: 16),
          // Source text
          const Text(
            'Teks Asli:',
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
          const SizedBox(height: 2),
          Text(
            sourceText,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Translated text
          const Text(
            'Terjemahan BISINDO:',
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.translatedText,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Stats row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildStatChip(Icons.text_snippet, '$charCount karakter'),
              _buildStatChip(Icons.short_text, '$wordCount kata'),
              _buildStatChip(Icons.speed, '$confidencePercent%'),
              _buildStatChip(Icons.psychology, 'AI v${AppConstants.appVersion}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedGesturesList() {
    final result = _translationResult!;
    if (result.matchedGestures.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textHint.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gesture yang Cocok',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...result.matchedGestures.map((gesture) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.sign_language,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gesture.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (gesture.description != null)
                          Text(
                            gesture.description!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      gesture.difficulty,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeedbackButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleFeedback(true),
            icon: const Icon(Icons.thumb_up_outlined, size: 16),
            label: const Text('Benar', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              side: const BorderSide(color: AppColors.success),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleFeedback(false),
            icon: const Icon(Icons.thumb_down_outlined, size: 16),
            label: const Text('Salah', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: CAMERA BISINDO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCameraTab() {
    if (_cameraPermissionDenied) {
      return _buildCameraPermissionUI();
    }

    if (_cameraInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Mempersiapkan kamera...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (!_cameraInitialized) {
      return _buildCameraPermissionUI();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCameraPreview(),
          const SizedBox(height: 12),
          _buildDetectionOverlay(),
          const SizedBox(height: 12),
          _buildSentenceBuilder(),
          const SizedBox(height: 12),
          _buildCameraActionButtons(),
          const SizedBox(height: 16),
          _buildAlphabetReference(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCameraPermissionUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Akses Kamera Diperlukan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Untuk mendeteksi bahasa isyarat BISINDO secara real-time, '
              'aplikasi memerlukan akses ke kamera perangkat Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.camera_alt, size: 20),
              label: const Text('Aktifkan Kamera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'Kamera tidak tersedia',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Use proper aspect ratio from camera to avoid squished preview
    final cameraAspectRatio = controller.value.aspectRatio;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 1 / cameraAspectRatio, // Invert for portrait mode
              child: CameraPreview(controller),
            ),
          ),
        ),
        // Camera switch button (front/back)
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _switchCamera,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.cameraswitch_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        // Camera indicator (front/back)
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _cameraService.isFrontCamera
                      ? Icons.camera_front
                      : Icons.camera_rear,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _cameraService.isFrontCamera ? 'Depan' : 'Belakang',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionOverlay() {
    final hasResult = _lastGestureResult != null &&
        _lastGestureResult!.detectedLetter != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasResult
            ? AppColors.success.withOpacity(0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasResult
              ? AppColors.success.withOpacity(0.3)
              : AppColors.textHint.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                hasResult ? Icons.check_circle : Icons.search,
                color: hasResult ? AppColors.success : AppColors.textHint,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasResult
                      ? 'Huruf Terdeteksi'
                      : (_isDetecting
                          ? 'Mendeteksi gesture...'
                          : 'Tekan tombol Mulai untuk deteksi'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: hasResult ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
              // Start/Stop detection button
              ElevatedButton.icon(
                onPressed: _isDetecting ? _stopDetection : _startDetection,
                icon: Icon(
                  _isDetecting ? Icons.stop : Icons.play_arrow,
                  size: 16,
                ),
                label: Text(
                  _isDetecting ? 'Stop' : 'Mulai',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isDetecting ? AppColors.error : AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          if (hasResult) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Center(
                    child: Text(
                      _lastGestureResult!.detectedLetter!,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Confidence: ${(_lastGestureResult!.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _lastGestureResult!.recognitionMethod == 'ai'
                                  ? Colors.deepPurple.withOpacity(0.15)
                                  : Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _lastGestureResult!.recognitionMethod == 'ai'
                                  ? 'AI'
                                  : 'Rule',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color:
                                    _lastGestureResult!.recognitionMethod == 'ai'
                                        ? Colors.deepPurple
                                        : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_lastGestureResult!.description.isNotEmpty)
                        Text(
                          _lastGestureResult!.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Add letter button
                IconButton(
                  onPressed: () {
                    _addLetterToSentence(_lastGestureResult!.detectedLetter!);
                  },
                  icon: const Icon(Icons.add_circle, size: 28),
                  color: AppColors.primary,
                  tooltip: 'Tambah huruf',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentenceBuilder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textHint.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teks yang Dibangun:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _builtSentence.isEmpty ? '(belum ada teks)' : _builtSentence,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _builtSentence.isEmpty
                    ? AppColors.textHint
                    : AppColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Action buttons row
          Row(
            children: [
              _buildSentenceActionBtn(
                icon: Icons.space_bar,
                label: 'Spasi',
                onTap: _addSpaceToSentence,
              ),
              const SizedBox(width: 8),
              _buildSentenceActionBtn(
                icon: Icons.backspace_outlined,
                label: 'Hapus',
                onTap: _backspaceSentence,
              ),
              const SizedBox(width: 8),
              _buildSentenceActionBtn(
                icon: Icons.clear_all,
                label: 'Bersihkan',
                onTap: _clearSentence,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _builtSentence.trim().isNotEmpty
                ? () => _handleSpeak(_builtSentence)
                : null,
            icon: const Icon(Icons.volume_up, size: 18),
            label: const Text('Ucapkan', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _builtSentence.trim().isNotEmpty
                ? _translateBuiltSentence
                : null,
            icon: const Icon(Icons.translate, size: 18),
            label: const Text('Terjemahkan', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  // ─── Alphabet Reference Grid ──────────────────────────────────────────────

  Widget _buildAlphabetReference() {
    final alphabets = BisindoAlphabetData.allAlphabets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Referensi Alfabet BISINDO',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ketuk huruf untuk melihat detail gesture',
          style: TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: alphabets.length,
          itemBuilder: (context, index) {
            final gesture = alphabets[index];
            return _buildAlphabetTile(gesture);
          },
        ),
      ],
    );
  }

  Widget _buildAlphabetTile(BisindoGesture gesture) {
    return Material(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _showAlphabetDetailDialog(gesture),
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(
            gesture.letter,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _showAlphabetDetailDialog(BisindoGesture gesture) {
    // Determine gesture image path
    final imagePath = 'assets/images/gestures/alphabet_${gesture.letter.toLowerCase()}.png';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    gesture.letter,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Huruf ${gesture.letter}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Text(
                gesture.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gesture image/illustration
                Container(
                  width: double.infinity,
                  height: 160,
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
                        // Fallback: show visual representation with emoji and hand illustration
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              gesture.emoji,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                gesture.handType == HandType.twoHand
                                    ? '🤲 Dua Tangan'
                                    : '🤚 Satu Tangan',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ilustrasi: ${gesture.description}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildDetailRow('Deskripsi', gesture.description),
                const SizedBox(height: 10),
                // Instruction with highlighted box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
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
                        gesture.instruction,
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
                _buildDetailRow(
                  'Tipe Tangan',
                  gesture.handType == HandType.twoHand
                      ? 'Dua Tangan'
                      : 'Satu Tangan',
                ),
                if (gesture.hasMotion) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.motion_photos_on,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 6),
                      const Text(
                        'Memerlukan gerakan',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // Finger pattern visual
                _buildFingerPatternRow(gesture.fingerPattern),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addLetterToSentence(gesture.letter);
                _showSnackBar(
                  'Huruf "${gesture.letter}" ditambahkan',
                  isError: false,
                );
              },
              child: const Text('Tambah ke Teks'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFingerPatternRow(FingerPattern pattern) {
    final fingers = [
      ('👍', 'Jempol', pattern.thumb),
      ('☝️', 'Telunjuk', pattern.index),
      ('🖕', 'Tengah', pattern.middle),
      ('💍', 'Manis', pattern.ring),
      ('🤙', 'Kelingking', pattern.pinky),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: fingers.map((f) {
          final isExtended = f.$3;
          return Column(
            children: [
              Text(f.$1, style: TextStyle(fontSize: 14, color: isExtended ? null : AppColors.textHint)),
              const SizedBox(height: 2),
              Icon(
                isExtended ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: isExtended ? AppColors.success : AppColors.textHint,
              ),
              Text(
                f.$2,
                style: TextStyle(
                  fontSize: 8,
                  color: isExtended ? AppColors.success : AppColors.textHint,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
