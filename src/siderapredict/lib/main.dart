import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siderapredict/app/config/app_config.dart';
import 'package:siderapredict/app/sidera_predict_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(statusBarStyle);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: '.env');
  AppConfig.validateOrThrow();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  List<CameraDescription> cameras = const <CameraDescription>[];
  try {
    cameras = await availableCameras();
  } catch (_) {}

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    SideraPredictApp(cameras: cameras, sharedPreferences: sharedPreferences),
  );
}
