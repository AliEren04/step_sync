# Step Sync

Step Sync is a Flutter package that uses the accelerometer and mathematical calculations to track the number of steps taken by a user. This package also provides a method to reset the step count. It is easy to use and has a simple API.

## Installation

To use Step Sync in your Flutter project, add the following line to your `pubspec.yaml` file:

```yaml
dependencies:
  step_sync: ^1.0.0  # Use the latest version
```


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

Once you have Step Sync installed in your project, you can use it to track and reset the step count. Here's how:

1. Import the Step Sync package in your Dart file:

```dart
import 'package:step_sync/step_sync.dart';
```
2.Create Instance of Our Class Called StepCounter

```dart
final stepCounter = StepCounter();
```
3.Access Steps Directly using .steps property
```dart
final currentSteps = stepCounter.steps; 
```
4. To Reset Steps use resetSteps method provided by StepCounter Class
```dart
stepCounter.resetSteps();
```

