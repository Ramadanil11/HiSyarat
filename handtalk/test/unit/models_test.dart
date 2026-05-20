import 'package:flutter_test/flutter_test.dart';
import 'package:handtalk/services/translation_service.dart';
import 'package:handtalk/services/history_service.dart';
import 'package:handtalk/services/feedback_service.dart';

void main() {
  group('VocabularyModel', () {
    test('fromMap creates model correctly', () {
      final map = {
        'id': 1,
        'word': 'Halo',
        'meaning': 'Hello',
        'category_id': 1,
        'gesture_id': 1,
        'difficulty': 'beginner',
        'usage_example': 'Halo, apa kabar?',
        'pronunciation_guide': 'ha-lo',
        'is_active': 1,
        'created_at': '2024-01-01T00:00:00.000',
      };

      final vocab = VocabularyModel.fromMap(map);

      expect(vocab.id, 1);
      expect(vocab.word, 'Halo');
      expect(vocab.meaning, 'Hello');
      expect(vocab.categoryId, 1);
      expect(vocab.gestureId, 1);
      expect(vocab.difficulty, 'beginner');
      expect(vocab.isActive, true);
    });

    test('fromMap handles defaults', () {
      final map = <String, dynamic>{};
      final vocab = VocabularyModel.fromMap(map);

      expect(vocab.word, '');
      expect(vocab.difficulty, 'beginner');
      expect(vocab.isActive, false); // is_active null -> false
    });

    test('toMap produces correct output', () {
      final vocab = VocabularyModel(
        id: 1,
        word: 'Terima Kasih',
        meaning: 'Thank you',
        categoryId: 2,
        difficulty: 'intermediate',
      );

      final map = vocab.toMap();

      expect(map['id'], 1);
      expect(map['word'], 'Terima Kasih');
      expect(map['meaning'], 'Thank you');
      expect(map['category_id'], 2);
      expect(map['difficulty'], 'intermediate');
      expect(map['is_active'], 1);
    });

    test('toMap omits null id', () {
      final vocab = VocabularyModel(word: 'Test');
      final map = vocab.toMap();

      expect(map.containsKey('id'), false);
    });
  });

  group('CategoryModel', () {
    test('fromMap creates model correctly', () {
      final map = {
        'id': 1,
        'name': 'Salam',
        'description': 'Kata salam dan sapaan',
        'icon_name': 'greeting',
        'color_hex': '#FF5722',
        'sort_order': 1,
        'is_active': 1,
        'created_at': '2024-01-01T00:00:00.000',
      };

      final category = CategoryModel.fromMap(map);

      expect(category.id, 1);
      expect(category.name, 'Salam');
      expect(category.description, 'Kata salam dan sapaan');
      expect(category.iconName, 'greeting');
      expect(category.sortOrder, 1);
      expect(category.isActive, true);
    });

    test('toMap produces correct output', () {
      final category = CategoryModel(
        id: 1,
        name: 'Keluarga',
        description: 'Anggota keluarga',
        iconName: 'family',
        colorHex: '#4CAF50',
        sortOrder: 2,
      );

      final map = category.toMap();

      expect(map['name'], 'Keluarga');
      expect(map['icon_name'], 'family');
      expect(map['sort_order'], 2);
    });
  });

  group('GestureModel', () {
    test('fromMap creates model correctly', () {
      final map = {
        'id': 1,
        'name': 'A',
        'description': 'Huruf A dalam BISINDO',
        'category_id': 1,
        'difficulty': 'beginner',
        'direction': 'static',
        'hand_type': 'right',
        'is_active': 1,
        'created_at': '2024-01-01T00:00:00.000',
      };

      final gesture = GestureModel.fromMap(map);

      expect(gesture.id, 1);
      expect(gesture.name, 'A');
      expect(gesture.difficulty, 'beginner');
      expect(gesture.direction, 'static');
      expect(gesture.handType, 'right');
    });

    test('fromMap handles defaults', () {
      final map = <String, dynamic>{};
      final gesture = GestureModel.fromMap(map);

      expect(gesture.name, '');
      expect(gesture.difficulty, 'beginner');
      expect(gesture.direction, 'static');
      expect(gesture.handType, 'both');
    });
  });

  group('TranslationResult', () {
    test('creates correctly with all fields', () {
      final result = TranslationResult(
        sourceText: 'Halo',
        translatedText: '[Halo]',
        confidence: 0.875,
        matchedVocabs: [],
        matchedGestures: [],
        direction: 'text_to_sign',
      );

      expect(result.sourceText, 'Halo');
      expect(result.translatedText, '[Halo]');
      expect(result.confidence, 0.875);
      expect(result.direction, 'text_to_sign');
      expect(result.matchedVocabs, isEmpty);
      expect(result.matchedGestures, isEmpty);
    });
  });

  group('HistoryModel', () {
    test('fromMap creates model correctly', () {
      final map = {
        'id': 1,
        'user_id': 1,
        'input_type': 'text',
        'input_data': 'Halo',
        'translated_text': '[Halo]',
        'confidence_score': 0.85,
        'processing_time_ms': 150,
        'is_correct': 1,
        'session_id': 'abc-123',
        'created_at': '2024-01-01T12:00:00.000',
        'source_text': 'Halo',
        'direction': 'text_to_sign',
      };

      final history = HistoryModel.fromMap(map);

      expect(history.id, 1);
      expect(history.userId, 1);
      expect(history.inputType, 'text');
      expect(history.confidenceScore, 0.85);
      expect(history.isCorrect, true);
      expect(history.translationDirection, 'text_to_sign');
    });

    test('fromMap handles null is_correct', () {
      final map = {
        'user_id': 1,
        'is_correct': null,
        'created_at': '2024-01-01T00:00:00.000',
      };

      final history = HistoryModel.fromMap(map);
      expect(history.isCorrect, isNull);
    });
  });

  group('FeedbackModel', () {
    test('fromMap creates model correctly', () {
      final map = {
        'id': 1,
        'user_id': 1,
        'type': 'translation',
        'subject': 'Terjemahan Benar',
        'message': 'Benar',
        'rating': 5,
        'related_translation_id': 10,
        'status': 'pending',
        'created_at': '2024-01-01T00:00:00.000',
      };

      final feedback = FeedbackModel.fromMap(map);

      expect(feedback.id, 1);
      expect(feedback.userId, 1);
      expect(feedback.type, 'translation');
      expect(feedback.rating, 5);
      expect(feedback.status, 'pending');
    });

    test('toMap produces correct output', () {
      final feedback = FeedbackModel(
        userId: 1,
        type: 'translation',
        message: 'Test feedback',
        rating: 3,
      );

      final map = feedback.toMap();

      expect(map['user_id'], 1);
      expect(map['type'], 'translation');
      expect(map['message'], 'Test feedback');
      expect(map['rating'], 3);
      expect(map.containsKey('id'), false);
    });
  });
}
