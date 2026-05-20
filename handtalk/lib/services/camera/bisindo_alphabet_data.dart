// BISINDO Alphabet Gesture Definitions
// Setiap huruf didefinisikan dengan deskripsi pose tangan
// dan instruksi visual untuk pengguna.
// BISINDO menggunakan DUA TANGAN untuk alfabet (berbeda dengan ASL yang 1 tangan)

/// Data alfabet BISINDO lengkap A-Z
class BisindoAlphabetData {
  BisindoAlphabetData._();

  /// Get all alphabet gestures
  static List<BisindoGesture> get allAlphabets => _alphabets;

  /// Get gesture by letter
  static BisindoGesture? getByLetter(String letter) {
    final upper = letter.toUpperCase();
    try {
      return _alphabets.firstWhere((g) => g.letter == upper);
    } catch (_) {
      return null;
    }
  }

  /// Get gesture by index (0-25 for A-Z)
  static BisindoGesture? getByIndex(int index) {
    if (index < 0 || index >= _alphabets.length) return null;
    return _alphabets[index];
  }

  static final List<BisindoGesture> _alphabets = [
    BisindoGesture(
      letter: 'A',
      description: 'Kepalan tangan, ibu jari di samping',
      instruction: 'Kepalkan tangan kiri, ibu jari tegak di samping. Tangan kanan menunjuk.',
      handType: HandType.twoHand,
      emoji: '\u{270A}', // fist
      fingerPattern: FingerPattern(thumb: true, index: false, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'B',
      description: 'Empat jari tegak rapat, ibu jari dilipat',
      instruction: 'Tegakkan 4 jari rapat, lipat ibu jari ke telapak tangan kiri.',
      handType: HandType.twoHand,
      emoji: '\u{1F590}', // hand with fingers splayed
      fingerPattern: FingerPattern(thumb: false, index: true, middle: true, ring: true, pinky: true),
    ),
    BisindoGesture(
      letter: 'C',
      description: 'Jari melengkung membentuk huruf C',
      instruction: 'Lengkungkan semua jari tangan kiri membentuk huruf C.',
      handType: HandType.twoHand,
      emoji: '\u{1F44C}',
      fingerPattern: FingerPattern(thumb: true, index: true, middle: true, ring: true, pinky: true, curved: true),
    ),
    BisindoGesture(
      letter: 'D',
      description: 'Telunjuk tegak, jari lain melingkar',
      instruction: 'Tegakkan telunjuk, jari lain melingkar menyentuh ibu jari.',
      handType: HandType.twoHand,
      emoji: '\u{261D}', // index pointing up
      fingerPattern: FingerPattern(thumb: true, index: true, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'E',
      description: 'Semua jari ditekuk ke telapak',
      instruction: 'Tekuk semua jari ke telapak tangan, ibu jari dilipat di bawah.',
      handType: HandType.twoHand,
      emoji: '\u{270A}',
      fingerPattern: FingerPattern(thumb: false, index: false, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'F',
      description: 'Ibu jari & telunjuk membentuk lingkaran, 3 jari tegak',
      instruction: 'Satukan ujung ibu jari dan telunjuk membentuk O, tegakkan 3 jari lainnya.',
      handType: HandType.twoHand,
      emoji: '\u{1F44C}', // OK hand
      fingerPattern: FingerPattern(thumb: true, index: true, middle: true, ring: true, pinky: true),
    ),
    BisindoGesture(
      letter: 'G',
      description: 'Telunjuk menunjuk ke samping, ibu jari sejajar',
      instruction: 'Arahkan telunjuk ke samping, ibu jari sejajar di atas.',
      handType: HandType.twoHand,
      emoji: '\u{1F449}', // pointing right
      fingerPattern: FingerPattern(thumb: true, index: true, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'H',
      description: 'Telunjuk & jari tengah tegak sejajar horizontal',
      instruction: 'Tegakkan telunjuk dan jari tengah sejajar, arahkan horizontal.',
      handType: HandType.twoHand,
      emoji: '\u{270C}', // victory
      fingerPattern: FingerPattern(thumb: false, index: true, middle: true, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'I',
      description: 'Kelingking tegak, jari lain mengepal',
      instruction: 'Tegakkan kelingking saja, kepalkan jari lainnya.',
      handType: HandType.twoHand,
      emoji: '\u{1F91F}',
      fingerPattern: FingerPattern(thumb: false, index: false, middle: false, ring: false, pinky: true),
    ),
    BisindoGesture(
      letter: 'J',
      description: 'Kelingking tegak lalu gerakkan melengkung',
      instruction: 'Tegakkan kelingking, gerakkan melengkung ke bawah membentuk J.',
      handType: HandType.twoHand,
      emoji: '\u{1F91F}',
      fingerPattern: FingerPattern(thumb: false, index: false, middle: false, ring: false, pinky: true),
      hasMotion: true,
    ),
    BisindoGesture(
      letter: 'K',
      description: 'Telunjuk tegak, jari tengah miring, ibu jari di antara',
      instruction: 'Tegakkan telunjuk, miringkan jari tengah, ibu jari di antara keduanya.',
      handType: HandType.twoHand,
      emoji: '\u{270C}',
      fingerPattern: FingerPattern(thumb: true, index: true, middle: true, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'L',
      description: 'Telunjuk tegak, ibu jari ke samping (sudut siku-siku)',
      instruction: 'Bentuk huruf L: telunjuk tegak ke atas, ibu jari ke samping.',
      handType: HandType.twoHand,
      emoji: '\u{1F44D}',
      fingerPattern: FingerPattern(thumb: true, index: true, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'M',
      description: 'Tiga jari menutupi ibu jari di telapak',
      instruction: 'Lipat ibu jari ke telapak, tutupi dengan telunjuk, jari tengah, dan jari manis.',
      handType: HandType.twoHand,
      emoji: '\u{270A}',
      fingerPattern: FingerPattern(thumb: false, index: false, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'N',
      description: 'Dua jari menutupi ibu jari di telapak',
      instruction: 'Lipat ibu jari ke telapak, tutupi dengan telunjuk dan jari tengah.',
      handType: HandType.twoHand,
      emoji: '\u{270A}',
      fingerPattern: FingerPattern(thumb: false, index: false, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'O',
      description: 'Semua jari melengkung membentuk lingkaran O',
      instruction: 'Lengkungkan semua jari membentuk lingkaran O.',
      handType: HandType.twoHand,
      emoji: '\u{1F44C}',
      fingerPattern: FingerPattern(thumb: true, index: true, middle: true, ring: true, pinky: true, curved: true),
    ),
    BisindoGesture(
      letter: 'P',
      description: 'Telunjuk ke bawah, jari tengah ke depan',
      instruction: 'Arahkan telunjuk ke bawah, jari tengah ke depan, ibu jari di antara.',
      handType: HandType.twoHand,
      emoji: '\u{1F447}', // pointing down
      fingerPattern: FingerPattern(thumb: true, index: true, middle: true, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'Q',
      description: 'Ibu jari dan telunjuk menunjuk ke bawah',
      instruction: 'Arahkan ibu jari dan telunjuk ke bawah bersamaan.',
      handType: HandType.twoHand,
      emoji: '\u{1F447}',
      fingerPattern: FingerPattern(thumb: true, index: true, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'R',
      description: 'Telunjuk dan jari tengah menyilang',
      instruction: 'Silangkan telunjuk dan jari tengah (telunjuk di depan).',
      handType: HandType.twoHand,
      emoji: '\u{1F91E}', // crossed fingers
      fingerPattern: FingerPattern(thumb: false, index: true, middle: true, ring: false, pinky: false, crossed: true),
    ),
    BisindoGesture(
      letter: 'S',
      description: 'Kepalan tangan, ibu jari di depan jari-jari',
      instruction: 'Kepalkan tangan, letakkan ibu jari di depan jari-jari yang mengepal.',
      handType: HandType.twoHand,
      emoji: '\u{270A}',
      fingerPattern: FingerPattern(thumb: true, index: false, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'T',
      description: 'Ibu jari diselipkan antara telunjuk dan jari tengah',
      instruction: 'Kepalkan tangan, selipkan ibu jari di antara telunjuk dan jari tengah.',
      handType: HandType.twoHand,
      emoji: '\u{270A}',
      fingerPattern: FingerPattern(thumb: true, index: false, middle: false, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'U',
      description: 'Telunjuk dan jari tengah tegak rapat',
      instruction: 'Tegakkan telunjuk dan jari tengah rapat bersamaan.',
      handType: HandType.twoHand,
      emoji: '\u{270C}',
      fingerPattern: FingerPattern(thumb: false, index: true, middle: true, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'V',
      description: 'Telunjuk dan jari tengah tegak terbuka (V)',
      instruction: 'Tegakkan telunjuk dan jari tengah terbuka membentuk huruf V.',
      handType: HandType.twoHand,
      emoji: '\u{270C}', // victory
      fingerPattern: FingerPattern(thumb: false, index: true, middle: true, ring: false, pinky: false),
    ),
    BisindoGesture(
      letter: 'W',
      description: 'Tiga jari tegak terbuka (W)',
      instruction: 'Tegakkan telunjuk, jari tengah, dan jari manis terbuka.',
      handType: HandType.twoHand,
      emoji: '\u{1F596}',
      fingerPattern: FingerPattern(thumb: false, index: true, middle: true, ring: true, pinky: false),
    ),
    BisindoGesture(
      letter: 'X',
      description: 'Telunjuk ditekuk membentuk kait',
      instruction: 'Tegakkan telunjuk lalu tekuk membentuk kait/hook.',
      handType: HandType.twoHand,
      emoji: '\u{261D}',
      fingerPattern: FingerPattern(thumb: false, index: true, middle: false, ring: false, pinky: false, curved: true),
    ),
    BisindoGesture(
      letter: 'Y',
      description: 'Ibu jari dan kelingking tegak (shaka)',
      instruction: 'Tegakkan ibu jari dan kelingking, kepalkan 3 jari tengah.',
      handType: HandType.twoHand,
      emoji: '\u{1F919}', // call me hand
      fingerPattern: FingerPattern(thumb: true, index: false, middle: false, ring: false, pinky: true),
    ),
    BisindoGesture(
      letter: 'Z',
      description: 'Telunjuk menggambar huruf Z di udara',
      instruction: 'Tegakkan telunjuk, gambar huruf Z di udara.',
      handType: HandType.twoHand,
      emoji: '\u{261D}',
      fingerPattern: FingerPattern(thumb: false, index: true, middle: false, ring: false, pinky: false),
      hasMotion: true,
    ),
  ];
}

/// Represents a single BISINDO gesture
class BisindoGesture {
  final String letter;
  final String description;
  final String instruction;
  final HandType handType;
  final String emoji;
  final FingerPattern fingerPattern;
  final bool hasMotion;

  const BisindoGesture({
    required this.letter,
    required this.description,
    required this.instruction,
    required this.handType,
    required this.emoji,
    required this.fingerPattern,
    this.hasMotion = false,
  });
}

/// Finger pattern for gesture recognition
class FingerPattern {
  final bool thumb;
  final bool index;
  final bool middle;
  final bool ring;
  final bool pinky;
  final bool curved;
  final bool crossed;

  const FingerPattern({
    required this.thumb,
    required this.index,
    required this.middle,
    required this.ring,
    required this.pinky,
    this.curved = false,
    this.crossed = false,
  });

  /// Count extended fingers
  int get extendedCount {
    int count = 0;
    if (thumb) count++;
    if (index) count++;
    if (middle) count++;
    if (ring) count++;
    if (pinky) count++;
    return count;
  }

  /// Convert to list of booleans [thumb, index, middle, ring, pinky]
  List<bool> toList() => [thumb, index, middle, ring, pinky];

  /// Calculate similarity score with another pattern (0.0 - 1.0)
  double similarity(FingerPattern other) {
    int matches = 0;
    if (thumb == other.thumb) matches++;
    if (index == other.index) matches++;
    if (middle == other.middle) matches++;
    if (ring == other.ring) matches++;
    if (pinky == other.pinky) matches++;
    return matches / 5.0;
  }
}

enum HandType { oneHand, twoHand }
