import 'dart:async';

class TimerState {
  final int targetSeconds;
  final int elapsedSeconds;
  final int remainingSeconds;
  final double progress; // 0.0 to 1.0
  final bool isRunning;
  final bool isPaused;
  final bool isCompleted;

  const TimerState({
    required this.targetSeconds,
    this.elapsedSeconds = 0,
    this.remainingSeconds = 0,
    this.progress = 0.0,
    this.isRunning = false,
    this.isPaused = false,
    this.isCompleted = false,
  });

  String get formattedRemaining {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    final h = m ~/ 60;
    if (h > 0) {
      final remM = m % 60;
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedElapsed {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    final h = m ~/ 60;
    if (h > 0) {
      final remM = m % 60;
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class TimerService {
  Timer? _ticker;
  final _stateController = StreamController<TimerState>.broadcast();

  Stream<TimerState> get stateStream => _stateController.stream;

  DateTime? _sessionStartTime;
  DateTime? _lastPauseTime;
  int _targetSeconds = 0;
  int _accumulatedPausedSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isCompleted = false;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isCompleted => _isCompleted;
  int get targetSeconds => _targetSeconds;

  void start(int targetSeconds) {
    _targetSeconds = targetSeconds;
    _sessionStartTime = DateTime.now();
    _lastPauseTime = null;
    _accumulatedPausedSeconds = 0;
    _isRunning = true;
    _isPaused = false;
    _isCompleted = false;

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  void pause() {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _lastPauseTime = DateTime.now();
    _tick();
  }

  void resume() {
    if (!_isRunning || !_isPaused) return;
    if (_lastPauseTime != null) {
      _accumulatedPausedSeconds += DateTime.now()
          .difference(_lastPauseTime!)
          .inSeconds;
      _lastPauseTime = null;
    }
    _isPaused = false;
    _tick();
  }

  void stop() {
    _isRunning = false;
    _isPaused = false;
    _ticker?.cancel();
    _sessionStartTime = null;
    _lastPauseTime = null;
  }

  void _tick() {
    if (_sessionStartTime == null) return;

    int currentElapsed = 0;
    if (_isPaused && _lastPauseTime != null) {
      final runningDuration = _lastPauseTime!
          .difference(_sessionStartTime!)
          .inSeconds;
      currentElapsed = runningDuration - _accumulatedPausedSeconds;
    } else {
      final totalDuration = DateTime.now()
          .difference(_sessionStartTime!)
          .inSeconds;
      currentElapsed = totalDuration - _accumulatedPausedSeconds;
    }

    if (currentElapsed < 0) currentElapsed = 0;
    final int remaining = (_targetSeconds - currentElapsed).clamp(
      0,
      _targetSeconds,
    );
    final double progress = _targetSeconds > 0
        ? (currentElapsed / _targetSeconds).clamp(0.0, 1.0)
        : 1.0;

    if (remaining <= 0 && !_isCompleted) {
      _isCompleted = true;
      _isRunning = false;
      _ticker?.cancel();
    }

    _stateController.add(
      TimerState(
        targetSeconds: _targetSeconds,
        elapsedSeconds: currentElapsed,
        remainingSeconds: remaining,
        progress: progress,
        isRunning: _isRunning,
        isPaused: _isPaused,
        isCompleted: _isCompleted,
      ),
    );
  }

  void dispose() {
    _ticker?.cancel();
  }
}
