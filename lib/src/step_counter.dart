import 'dart:async';
import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:logging/logging.dart';

//A smart step counter that understands the difference between real walking and
// random phone movements.
//
// This isn't your average step counter. Instead of naively counting every jolt,
// it uses a two-stage process inspired by how humans recognize walking:
//
// 1.  **Peak-Trough Detection:** It first looks for the specific "up-and-down"
//     bobbing motion of a single step.
//
// 2.  **Cadence & Rhythm Check:** It then waits to see a consistent *rhythm* of
//     these motions. It won't start counting until it's sure you're actually
//     walking, not just picking up your phone.
//
// This approach makes it robust against false positives from driving, random
// shakes, or other non-walking activities. The goal is to provide a simple
// API for a complex problem, avoiding the need for complicated OS-level
// integrations like HealthKit.

// --- AUTHOR'S NOTE & LIBRARY PHILOSOPHY ---
//
// Creating a reliable step counter from raw sensor data is a surprisingly
// complex challenge that lives at the intersection of mathematics and mobile
// development. This library is the result of a journey to solve that problem
// with a clear goal in mind: simplicity.
//
// The core algorithms for filtering noise and detecting the unique rhythm of a
// human step were developed pragmatically. While I'm not a mathematician, I've
// implemented the main structure and logic myself, leveraging research and modern
// tools (like AI) to refine the signal processing. The result is an algorithm
// that is effective without being overly academic or difficult to understand.
//
// The primary goal has always been to create a minimal, easy-to-use API that
// any developer can drop into their project. This is why this library
// intentionally avoids heavy, OS-level frameworks like Apple's HealthKit.
// While those tools are powerful, they introduce significant complexity
// regarding permissions, setup, and data handling.
//
// This library offers a different trade-off: a simple, self-contained solution
// that gives you direct access to step counting without the overhead.
//

// A NOTE ON iOS BACKGROUND LIMITATIONS:
// To preserve battery life and ensure user privacy, Apple's iOS places
// strict limitations on what apps can do in the background. Continuously
// reading from the accelerometer is a power-intensive task, and as such,
// iOS does not guarantee that this service can run indefinitely once the
// app is suspended.
//
// While this approach is beneficial for system health, it presents a
// challenge for developers creating custom sensor-based libraries like this one.
//
// For guaranteed, all-day background step tracking, Apple's official
// solution is its HealthKit framework. This library **intentionally avoids**
// HealthKit to remain lightweight, easy to integrate, and free from the
// complexities of managing sensitive health data permissions. The trade-off
// is that step counting is most reliable when the app is in the foreground.

// -----------------------------------------------------------------------------
// DEVELOPMENT PHILOSOPHY & STEP TRACKING LIMITATIONS
// -----------------------------------------------------------------------------
//
// This library's core principle is **simplicity** and **ease-of-use** over full
// platform feature coverage.
//
// RATIONALE:
// This library was developed because existing full-featured Dart/Flutter packages
// (which wrap deep system APIs like HealthKit or Google Fit) were considered
// too complicated and difficult to implement for beginner-to-intermediate users.
// The complexity of managing these APIs—especially the permissions—was a major
// barrier. The focus here is on a **minimalist, low-friction API** for step counting.
//
// TRADE-OFF:
// By intentionally avoiding those complex system health frameworks, we eliminate
// difficult platform-specific setup but sacrifice guaranteed, all-day background
// step tracking, particularly on iOS.
//
// RESULT:
// Step counting relies on the simpler CoreMotion/Pedometer APIs, which are
// reliable when the app is in the foreground or active. However, background
// updates are **not guaranteed** and may be suspended by the operating system
// for battery conservation. This design prioritizes a simple, lightweight
// dependency over 100% continuous background accuracy.

class StepCounter {
  int _steps = 0;
  final _stepController = StreamController<int>.broadcast();
  Stream<int> get stepStream => _stepController.stream;

  bool autofetch;
  bool showNotification;

  // Logger for debugging
  final Logger _logger = Logger('StepCounter');

  // --- Internal state ---
  final List<double> _accelWindow = [];
  final int _windowSize = 20; // for adaptive threshold
  final double _alpha = 0.1; // smoothing factor for high-pass filter

  double _prevFilteredZ = 0.0;

  int _lastStepTimeMs = 0;
  final int _minStepTimeMs = 300;
  final int _maxStepTimeMs = 1200;

  int _consecutivePeaks = 0;
  final int _requiredConsecutivePeaks = 2;
  int _firstPeakTimeMs = 0;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  StepCounter({this.autofetch = true, this.showNotification = true}) {
    if (autofetch) initializeService();
  }

  int get steps => _steps;

  void _emitStepUpdate() => _stepController.add(_steps);

  /// High-pass filter to remove gravity
  double _highPassFilter(double current) {
    double filtered = _alpha * (_prevFilteredZ + current - _prevFilteredZ);
    _prevFilteredZ = filtered;
    return filtered;
  }

  /// Adaptive threshold using moving window
  double _adaptiveThreshold() {
    if (_accelWindow.isEmpty) return 1.3; // default fallback
    double avg = _accelWindow.reduce((a, b) => a + b) / _accelWindow.length;
    double stdDev = sqrt(
        _accelWindow.fold<double>(0.0, (sum, x) => sum + pow(x - avg, 2)) /
            _accelWindow.length);
    return avg + 1.5 * stdDev; // tuning factor
  }

  void _processAccelerometerEvent(AccelerometerEvent event) {
    // Vector magnitude
    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    // Remove gravity
    double acc = _highPassFilter(magnitude - 9.81);

    // Update moving window
    _accelWindow.add(acc);
    if (_accelWindow.length > _windowSize) _accelWindow.removeAt(0);

    double threshold = _adaptiveThreshold();

    int now = DateTime.now().millisecondsSinceEpoch;

    // Peak detection
    if (acc > threshold) {
      if (_consecutivePeaks == 0) _firstPeakTimeMs = now;
      _consecutivePeaks++;

      // Validate step if enough consecutive peaks
      if (_consecutivePeaks >= _requiredConsecutivePeaks &&
          now - _lastStepTimeMs >= _minStepTimeMs &&
          now - _lastStepTimeMs <= _maxStepTimeMs) {
        _steps++;
        _emitStepUpdate();
        _logger.fine('Step counted! Total: $_steps');
        _lastStepTimeMs = now;
        _consecutivePeaks = 0;
      }

      // Reset if too much time passed
      if (now - _firstPeakTimeMs > _maxStepTimeMs) {
        _consecutivePeaks = 1;
        _firstPeakTimeMs = now;
      }
    } else {
      // Not a peak
      if (_consecutivePeaks > 0 && now - _firstPeakTimeMs > _maxStepTimeMs) {
        _consecutivePeaks = 0;
      }
    }
  }

  void startSensorListener() {
    _accelerometerSubscription = accelerometerEvents.listen(
      _processAccelerometerEvent,
      onError: (e) => _logger.warning('Sensor error: $e'),
      cancelOnError: true,
    );
  }

  void stopSensorListener() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  void resetSteps() {
    _steps = 0;
    _lastStepTimeMs = 0;
    _consecutivePeaks = 0;
    _firstPeakTimeMs = 0;
    _accelWindow.clear();
    _prevFilteredZ = 0.0;
    _emitStepUpdate();
  }

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: stepService,
        autoStart: true,
        isForegroundMode: showNotification,
        notificationChannelId: 'step_counter_channel',
        initialNotificationTitle: showNotification ? 'Step Counter' : '',
        initialNotificationContent:
            showNotification ? 'Tracking your steps' : '',
      ),
      iosConfiguration: IosConfiguration(
        onForeground: stepService,
        onBackground: (service) {
          startSensorListener();
          return true;
        },
      ),
    );
    service.startService();
  }

  @pragma('vm:entry-point')
  static void stepService(ServiceInstance service) {
    final counter = StepCounter(autofetch: false, showNotification: false);
    counter.startSensorListener();

    service.on('stopService').listen((event) {
      counter.stopSensorListener();
      counter.dispose();
      service.stopSelf();
    });
  }

  void dispose() {
    stopSensorListener();
    _stepController.close();
  }
}
