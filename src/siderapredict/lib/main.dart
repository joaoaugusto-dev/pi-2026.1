import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:siderapredict/app/app_widget.dart';
import 'package:siderapredict/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(statusBarStyle);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint(
        'Autenticado anonimamente: ${FirebaseAuth.instance.currentUser?.uid}',
      );
    }
  } catch (e) {
    debugPrint('Erro ao inicializar Firebase ou Autenticar: $e');
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    await dotenv.load(isOptional: true);
  }

  List<CameraDescription> cameras = const <CameraDescription>[];
  try {
    cameras = await availableCameras();
  } catch (_) {}

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(AppWidget(cameras: cameras, sharedPreferences: sharedPreferences));
}
