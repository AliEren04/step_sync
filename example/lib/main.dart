import 'package:flutter/material.dart';
import 'package:step_sync/step_sync.dart'; 

void main() {
  runApp(const MyApp());
}

/// The root of the app
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

/// A screen that displays the current step count.
class StepCounterScreen extends StatefulWidget {
  const StepCounterScreen({super.key}); 

  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen> {
  final StepCounter stepCounter = StepCounter(); // Create package's instance which step counter's instance 

  @override
  void initState() {
    super.initState();
    stepCounter.updateSteps(); // Start listening to step updates
  }

  @override
  void dispose() {
    stepCounter.dispose(); // Nice practice to clean up stream
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step Counter')),
      body: Center(
        child: StreamBuilder<int>(
          stream: stepCounter.stepStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(); 
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Steps Taken: ${snapshot.data}',
                    style: const TextStyle(fontSize: 24), 
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: stepCounter.resetSteps, 
                    child: const Text('Reset Steps'),
                  ),
                ],
              );
            } else {
              return const Text('No data available');
            }
          },
        ),
      ),
    );
  }
}
