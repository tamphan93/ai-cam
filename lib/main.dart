import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/camera_store.dart';
import 'screens/home_grid_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TapoViewerApp());
}

class TapoViewerApp extends StatelessWidget {
  const TapoViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CameraStore()..load(),
      child: MaterialApp(
        title: 'Tapo C200 Viewer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
        ),
        home: const HomeGridScreen(),
      ),
    );
  }
}
