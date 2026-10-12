import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      // Failed requests show an error with a "Try again" button instead of
      // Riverpod 3's silent automatic retries.
      retry: (_, _) => null,
      child: const StudentApp(),
    ),
  );
}
