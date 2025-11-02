import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'models/patient.dart';
import 'models/patient_type.dart';
import 'providers/patient_provider.dart';
import 'screens/patient_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(PatientTypeAdapter());
  Hive.registerAdapter(PatientAdapter());

  // TEMPORARY: Clear old data due to schema change
  // Remove this after first run with new schema
  // debugPrint('Clearing old patients box due to schema change...');
  // await Hive.deleteBoxFromDisk('patients');

  // Open the patients box
  await Hive.openBox<Patient>('patients');

  runApp(const ObSignoutApp());
}

class ObSignoutApp extends StatelessWidget {
  const ObSignoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PatientProvider(),
      child: MaterialApp(
        title: 'OB Signout',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1976D2), // Medical blue
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            elevation: 4,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1976D2),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        ),
        themeMode: ThemeMode.system,
        home: const PatientListScreen(),
      ),
    );
  }
}
