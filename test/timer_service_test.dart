import 'package:flutter_test/flutter_test.dart';
import 'package:habit_forge/core/services/timer_service.dart';

void main() {
  group('TimerService Tests', () {
    late TimerService timerService;

    setUp(() {
      timerService = TimerService();
    });

    tearDown(() {
      timerService.dispose();
    });

    test('TimerState formatted durations', () {
      const state1 = TimerState(
        targetSeconds: 120,
        elapsedSeconds: 45,
        remainingSeconds: 75,
        progress: 0.375,
      );

      expect(state1.formattedRemaining, equals('01:15'));
      expect(state1.formattedElapsed, equals('00:45'));

      const state2 = TimerState(
        targetSeconds: 3665,
        elapsedSeconds: 3600,
        remainingSeconds: 65,
      );

      expect(state2.formattedRemaining, equals('01:05'));
      expect(state2.formattedElapsed, equals('01:00:00'));
    });

    test('Timer start sets initial running state', () {
      timerService.start(60);
      expect(timerService.isRunning, isTrue);
      expect(timerService.isPaused, isFalse);
      expect(timerService.targetSeconds, equals(60));
    });

    test('Timer pause and resume state changes', () {
      timerService.start(60);
      timerService.pause();
      expect(timerService.isPaused, isTrue);

      timerService.resume();
      expect(timerService.isPaused, isFalse);
      expect(timerService.isRunning, isTrue);

      timerService.stop();
      expect(timerService.isRunning, isFalse);
    });
  });
}
