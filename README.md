# Step Sync

Step Sync is a Flutter package that uses the accelerometer and mathematical calculations to track the number of steps taken by a user with help of sensors other sensor libraries and mathematical calculations(algorithms Vector math package). This package also provides a method to reset the step count. It is easy to use and has a simple API.

## Installation

To use Step Sync in your Flutter project, add the following line to your `pubspec.yaml` file or flutter pub add step_sync then flutter pub get:

```yaml
dependencies:
  step_sync: ^3.0.0  # Use the latest version
```

## Features (v3)
- **Highly Accurate**: Filters out minor shakes, desk movements, and phone lifts.
- **Background Support**: Runs in the background on Android; foreground-only on iOS (system constraints).
- **Simple API**: Easy to integrate and use.
- **Reset Steps**: Clear your step count anytime.
- **Lightweight**: No heavy dependencies or complex permissions.


Here's what you need to do for both platforms:

Android (AndroidManifest.xml):

    Open the android/app/src/main/AndroidManifest.xml file in your Flutter project.
    To request access to the accelerometer sensor, add the following line within the <manifest> element

  ```xml
    <uses-permission android:name="android.permission.BODY_SENSORS" />

```

Open the ios/Runner/Info.plist file in your Flutter project.

To access the accelerometer, you don't need to specify a permission. However, you should include a description of why you need this data. Add the following key-value pair within the <dict> element:

```xml
<key>NSMotionUsageDescription</key>
<string>The app needs to access the accelerometer to count your steps.</string>
```

## Usage
Example User Interface
```dart
import 'package:flutter/material.dart';
import 'package:step_sync/step_sync.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

/// Root of the app
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step Counter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StepCounterScreen(),
    );
  }
}

/// Screen that displays the step count
class StepCounterScreen extends StatefulWidget {
  const StepCounterScreen({super.key});

  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen> {
  final StepCounter stepCounter = StepCounter(); // Instance from the library

  @override
  void initState() {
    super.initState();
    stepCounter.updateSteps(); // Start listening for step updates
  }

  @override
  void dispose() {
    stepCounter.dispose(); // Clean up resources when screen is removed
    super.dispose();
  }

  /// Optional: Throttle updates if steps are coming too fast
  Stream<int> get throttledStepStream {
    // Example: Only emit every 5 steps to reduce UI rebuilds
    return stepCounter.stepStream.transform(
      StreamTransformer.fromHandlers(
        handleData: (stepCount, sink) {
          if (stepCount % 5 == 0) {
            sink.add(stepCount);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step Counter')),
      body: Center(
        child: StreamBuilder<int>(
          // Use the throttled stream or stepCounter.stepStream directly
          stream: throttledStepStream,
          initialData: 0, // Show 0 immediately before first stream value
          builder: (context, snapshot) {
            // Error handling
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            // Safely get the current step count
            final steps = snapshot.data ?? 0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Steps Taken: $steps',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: stepCounter.resetSteps, // Reset steps to 0
                  child: const Text('Reset Steps'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

```
