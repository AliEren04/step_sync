import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:ui'; 


class StepCounter {
  int _steps = 0;
  final _stepController = StreamController<int>.broadcast();  // Stream to emit step count updates
  Stream<int> get stepStream => _stepController.stream;  // Expose stream to UI

  double threshold = 10.00;
  bool autofetch = true;

  StepCounter() {
    if (autofetch) {
      initializeService();
    }
  }

  int get steps => _steps;  // Getter to access the step count

  void _emitStepUpdate() {
    _stepController.add(_steps);  // Emit the updated step count to the stream
  }

  void updateSteps() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      double x = event.x;
      double y = event.y;
      double z = event.z;
      final acceleration = Vector3(x, y, z);
      final magnitude = acceleration.length;

      if (magnitude > threshold) {
        _steps++;
        _emitStepUpdate();  // Emit step update to the stream
      }
    });
  }

  void resetSteps() {
    _steps = 0;
    _emitStepUpdate();  // Emit reset step count
  }

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: stepService,
        isForegroundMode: true,  // Keep running in the background
      ),
      iosConfiguration: IosConfiguration(
        onForeground: stepService,
        onBackground: (service) {
          updateSteps();  // Continue updating steps in the background
          return true;
        },
      ),
    );

    service.startService();
  }

  Future<void> stepService(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      updateSteps();  // Update steps every second in the background
    });
  }

  void dispose() {
    _stepController.close();  // Clean up the stream when done
  }
}
