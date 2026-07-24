import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/util/crash_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashLog.install();
  runApp(const ProviderScope(child: CmfApp()));
}
