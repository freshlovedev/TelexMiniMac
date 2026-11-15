import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.load();
  controller.startNativeMonitoring();
  runApp(TelexMiniApp(controller: controller));
}
