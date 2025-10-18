import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class PomodoroService extends ChangeNotifier {
  PomodoroService({Duration? initialDuration})
      : _defaultDuration = initialDuration ?? const Duration(minutes: 35) {
    _remaining = _defaultDuration;
    _lastSetDuration = _defaultDuration;
  }

  final Duration _defaultDuration;
  Duration _remaining = Duration.zero;
  Duration _lastSetDuration = Duration.zero;
  DateTime? _endAtUtc; // for background-safe countdown
  Timer? _ticker;
  bool _isRunning = false;
  bool _isPaused = false;
  final StreamController<void> _finishedController = StreamController<void>.broadcast();

  Stream<void> get onFinished => _finishedController.stream;

  Duration get remaining => _remaining;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  void increaseByFiveMinutes() {
    if (_isRunning) return;
    _remaining += const Duration(minutes: 5);
    _lastSetDuration = _remaining;
    developer.log('Duration increased: $_remaining', name: 'PomodoroService');
    notifyListeners();
  }

  void decreaseByFiveMinutes() {
    if (_isRunning) return;
    final Duration next = _remaining - const Duration(minutes: 5);
    _remaining = next.inMinutes < 5 ? const Duration(minutes: 5) : next;
    _lastSetDuration = _remaining;
    developer.log('Duration decreased: $_remaining', name: 'PomodoroService');
    notifyListeners();
  }

  void reset() {
    _cancelTicker();
    _isRunning = false;
    _isPaused = false;
    _remaining = _lastSetDuration;
    _endAtUtc = null;
    developer.log('Timer reset to last set duration: $_lastSetDuration', name: 'PomodoroService');
    notifyListeners();
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;
    _endAtUtc = DateTime.now().toUtc().add(_remaining);
    developer.log('Timer started, ends at $_endAtUtc', name: 'PomodoroService');
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _cancelTicker();
    // Freeze remaining
    _remaining = _computeRemainingFromNow();
    developer.log('Timer paused, remaining: $_remaining', name: 'PomodoroService');
    notifyListeners();
  }

  void resume() {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;
    _endAtUtc = DateTime.now().toUtc().add(_remaining);
    developer.log('Timer resumed, ends at $_endAtUtc', name: 'PomodoroService');
    _startTicker();
    notifyListeners();
  }

  void setPresetDuration(Duration duration) {
    if (_isRunning) return;
    _remaining = duration;
    _lastSetDuration = duration;
    developer.log('Preset duration set: $duration', name: 'PomodoroService');
    notifyListeners();
  }

  void _startTicker() {
    _cancelTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final Duration left = _computeRemainingFromNow();
      if (left.isNegative || left.inSeconds <= 0) {
        _remaining = Duration.zero;
        _isRunning = false;
        _isPaused = false;
        _cancelTicker();
        developer.log('Timer finished', name: 'PomodoroService');
        notifyListeners();
        // Emit finished event for UI to react (dialog, notification)
        _finishedController.add(null);
        return;
      }
      _remaining = left;
      notifyListeners();
    });
  }

  Duration _computeRemainingFromNow() {
    if (_endAtUtc == null) return _remaining;
    final DateTime now = DateTime.now().toUtc();
    final Duration left = _endAtUtc!.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _cancelTicker();
    _finishedController.close();
    super.dispose();
  }
}


