/// HandTalk Audio/TTS Service
/// Singleton pattern - satu instance untuk seluruh aplikasi
/// Mengelola text-to-speech menggunakan flutter_tts

import 'package:flutter_tts/flutter_tts.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Service: AudioService (Singleton)
// ═══════════════════════════════════════════════════════════════════════════════

/// Service audio/TTS - singleton karena stateful (menyimpan state FlutterTts)
class AudioService {
  AudioService._internal();
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  /// Instance FlutterTts
  final FlutterTts _tts = FlutterTts();

  /// Status apakah TTS sudah diinisialisasi
  bool _isInitialized = false;

  // ─── Inisialisasi TTS ─────────────────────────────────────────────────────

  /// Inisialisasi konfigurasi TTS
  /// Bahasa: Indonesia (id-ID), kecepatan: 0.5, volume: 1.0
  Future<void> init() async {
    if (_isInitialized) return;

    // Set bahasa Indonesia
    await _tts.setLanguage('id-ID');

    // Set kecepatan bicara (0.0 - 1.0, default 0.5)
    await _tts.setSpeechRate(0.5);

    // Set volume (0.0 - 1.0, default 1.0)
    await _tts.setVolume(1.0);

    // Set pitch (0.5 - 2.0, default 1.0)
    await _tts.setPitch(1.0);

    _isInitialized = true;
  }

  // ─── Membacakan Teks ──────────────────────────────────────────────────────

  /// Membacakan teks menggunakan TTS
  /// Pastikan init() sudah dipanggil sebelumnya
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }

    if (text.trim().isEmpty) return;

    await _tts.speak(text);
  }

  // ─── Menghentikan TTS ─────────────────────────────────────────────────────

  /// Menghentikan pembacaan teks yang sedang berlangsung
  Future<void> stop() async {
    await _tts.stop();
  }
}
