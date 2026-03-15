import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AlarmScreen extends StatefulWidget {
  final String medicineName;
  final String dosage;
  final String purpose;
  final int notificationId;

  const AlarmScreen({
    super.key,
    required this.medicineName,
    required this.dosage,
    required this.purpose,
    required this.notificationId,
  });

  factory AlarmScreen.fromPayload(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return AlarmScreen(
        medicineName: map['name'] as String? ?? 'Medicine',
        dosage:       map['dosage'] as String? ?? '',
        purpose:      map['purpose'] as String? ?? '',
        notificationId: map['id'] as int? ?? 0,
      );
    } catch (_) {
      return const AlarmScreen(
          medicineName: 'Medicine', dosage: '', purpose: '', notificationId: 0);
    }
  }

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late FlutterTts _tts;
  Timer? _repeatTimer;
  bool _isSpeaking = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.88, end: 1.12).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glow  = Tween<double>(begin: 20, end: 48).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    await _speak();
    _repeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (mounted) await _speak();
    });
  }

  Future<void> _speak() async {
    if (_isSpeaking) return;
    _isSpeaking = true;
    try {
      final parts = <String>['Time to take ${widget.medicineName}'];
      if (widget.dosage.isNotEmpty) parts.add(widget.dosage);
      if (widget.purpose.isNotEmpty) parts.add('for ${widget.purpose}');
      parts.add('Please take it now.');
      await _tts.speak(parts.join('. '));
    } catch (e) { debugPrint('[AlarmScreen] TTS error: $e'); }
    finally { _isSpeaking = false; }
  }

  Future<void> _dismiss() async {
    _repeatTimer?.cancel();
    await _tts.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _tts.stop();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0E27), Color(0xFF0D1B3E), Color(0xFF1A2A5E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Background glow circles (decorative)
                Positioned(
                  top: -60, left: -60,
                  child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4FC3F7).withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40, right: -40,
                  child: Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7C4DFF).withOpacity(0.08),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // "Time for Medicine" label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alarm_rounded,
                              color: Color(0xFF4FC3F7), size: 18),
                          const SizedBox(width: 8),
                          Text('Time for Medicine',
                              style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Pulsing icon
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 150, height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFF1E4D8F), Color(0xFF0D2B5E)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4FC3F7)
                                    .withOpacity(0.45),
                                blurRadius: _glow.value,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.medication_rounded,
                              size: 76, color: Color(0xFF4FC3F7)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Medicine name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        widget.medicineName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF4FC3F7),
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.dosage.isNotEmpty || widget.purpose.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          [
                            if (widget.dosage.isNotEmpty) widget.dosage,
                            if (widget.purpose.isNotEmpty)
                              'for ${widget.purpose}',
                          ].join(' · '),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // Dismiss button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 56),
                      child: AppTheme.gradientButton(
                        onPressed: _dismiss,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0288D1), Color(0xFF4FC3F7)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        height: 64,
                        radius: 20,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text('Dismiss',
                                style: GoogleFonts.nunito(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
