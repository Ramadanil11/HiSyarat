/// HandTalk - Animated Hand Gesture Widget
/// Menampilkan animasi visual pola jari untuk setiap huruf BISINDO
/// Digunakan di kamus dan detail gestur

import 'package:flutter/material.dart';
import '../core/themes.dart';
import '../services/camera/bisindo_alphabet_data.dart';

/// Widget animasi tangan yang menunjukkan pola jari BISINDO
class AnimatedHandGesture extends StatefulWidget {
  final BisindoGesture gesture;
  final double size;
  final bool autoPlay;

  const AnimatedHandGesture({
    super.key,
    required this.gesture,
    this.size = 200,
    this.autoPlay = true,
  });

  @override
  State<AnimatedHandGesture> createState() => _AnimatedHandGestureState();
}

class _AnimatedHandGestureState extends State<AnimatedHandGesture>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fingerAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _motionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fingerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _motionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
      ),
    );

    if (widget.autoPlay) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Animasi isyarat huruf ${widget.gesture.letter}. '
          '${widget.gesture.description}',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background glow
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: widget.size * 0.7,
                    height: widget.size * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.08),
                          AppColors.primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Hand visualization
                _buildHandVisualization(),
                // Letter label
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.gesture.letter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Motion indicator
                if (widget.gesture.hasMotion)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Opacity(
                      opacity: _motionAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.motion_photos_on,
                          size: 16,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandVisualization() {
    final pattern = widget.gesture.fingerPattern;
    final fingers = [
      _FingerData('Jempol', pattern.thumb, -40, -20, -30),
      _FingerData('Telunjuk', pattern.index, -15, -50, -10),
      _FingerData('Tengah', pattern.middle, 5, -55, 0),
      _FingerData('Manis', pattern.ring, 25, -50, 10),
      _FingerData('Kelingking', pattern.pinky, 42, -40, 20),
    ];

    final animValue = _fingerAnimation.value;
    final motionOffset = widget.gesture.hasMotion
        ? _motionAnimation.value * 5
        : 0.0;

    return Transform.translate(
      offset: Offset(motionOffset, 0),
      child: SizedBox(
        width: widget.size * 0.6,
        height: widget.size * 0.6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Palm
            Positioned(
              bottom: 0,
              child: Container(
                width: 60,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Fingers
            ...fingers.map((finger) {
              final targetHeight = finger.isExtended ? 40.0 : 15.0;
              final currentHeight = 15.0 + (targetHeight - 15.0) * animValue;

              return Positioned(
                left: widget.size * 0.3 + finger.offsetX,
                bottom: 40,
                child: Transform.rotate(
                  angle: finger.angle * 3.14159 / 180 * animValue,
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fingertip
                      Container(
                        width: 10,
                        height: currentHeight,
                        decoration: BoxDecoration(
                          color: finger.isExtended
                              ? AppColors.primary.withOpacity(0.3 + 0.3 * animValue)
                              : AppColors.textHint.withOpacity(0.2),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                          border: Border.all(
                            color: finger.isExtended
                                ? AppColors.primary.withOpacity(0.6)
                                : AppColors.textHint.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Hand type indicator
            if (widget.gesture.handType == HandType.twoHand)
              Positioned(
                top: 0,
                left: 0,
                child: Opacity(
                  opacity: 0.5 + 0.5 * animValue,
                  child: const Icon(
                    Icons.pan_tool,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FingerData {
  final String name;
  final bool isExtended;
  final double offsetX;
  final double offsetY;
  final double angle;

  const _FingerData(
    this.name,
    this.isExtended,
    this.offsetX,
    this.offsetY,
    this.angle,
  );
}
