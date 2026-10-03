import 'package:flutter/material.dart';

import 'app.dart';
import 'di/get_di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetDI.init();

  runApp(const MyApp());
}
