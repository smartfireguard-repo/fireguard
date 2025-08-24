import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DevCreateDeviceIdsApp());
}

class DevCreateDeviceIdsApp extends StatelessWidget {
  const DevCreateDeviceIdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Create Device IDs',
      home: Scaffold(
        appBar: AppBar(title: const Text('Create Device IDs')),
        body: const Center(
          child: CreateDeviceIdsWidget(),
        ),
      ),
    );
  }
}

class CreateDeviceIdsWidget extends StatefulWidget {
  const CreateDeviceIdsWidget({super.key});

  @override
  State<CreateDeviceIdsWidget> createState() => _CreateDeviceIdsWidgetState();
}

class _CreateDeviceIdsWidgetState extends State<CreateDeviceIdsWidget> {
  String? _status;

  Future<void> _createSampleDeviceId() async {
    try {
      await FirebaseDatabase.instance.ref('device_ids/SAMPLE_DEVICE_001').set(true);
      setState(() {
        _status = 'Sample device ID created: SAMPLE_DEVICE_001';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _createSampleDeviceId,
          child: const Text('Create Sample Device ID'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 16),
          Text(_status!, style: const TextStyle(color: Colors.black)),
        ]
      ],
    );
  }
}
