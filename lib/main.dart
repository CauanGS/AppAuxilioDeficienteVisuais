import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tflite/tflite.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auxílio Deficientes Visuais',
      theme: ThemeData.dark(),
      home: CameraApp(),
    );
  }
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController _controller;
  bool _isDetecting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModel();
  }

  void _initCamera() {
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _startDetection();
    });
  }

  void _startDetection() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_controller.value.isInitialized && !_isDetecting) {
        _isDetecting = true;
        await _captureAndRunModel();
        _isDetecting = false;
      }
    });
  }

  Future<void> _captureAndRunModel() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final imagePath = path.join(tempDir.path, '${DateTime.now()}.jpg');

      await _controller.takePicture().then((XFile file) async {
        File image = File(file.path);
        var recognitions = await Tflite.runModelOnImage(
          path: image.path,
          numResults: 3,
          threshold: 0.5,
          imageMean: 127.5,
          imageStd: 127.5,
        );

        if (recognitions != null && recognitions.isNotEmpty) {
          print("Reconhecido: ${recognitions[0]['label']} com ${recognitions[0]['confidence']}");
          if (recognitions[0]['label'].toString().toLowerCase().contains('buraco')) {
            print("⚠️ Alerta: Inconformidade!");
          }
        }
      });
    } catch (e) {
      print("Erro ao capturar imagem: $e");
    }
  }

  Future<void> _loadModel() async {
    await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text("Detecção de Obstáculos")),
      body: CameraPreview(_controller),
    );
  }
}
