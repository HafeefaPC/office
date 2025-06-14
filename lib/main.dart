import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Add this import
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/screens/home_screen.dart';
import 'core/services/notification_service.dart';
import 'providers/attendance_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://dxkusdbluxpepeqpvmcw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4a3VzZGJsdXhwZXBlcXB2bWN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3NTEyNzEsImV4cCI6MjA2NTMyNzI3MX0.ZEUSFKao3gAp4e3hWMsTUxZXWrCmZ4Yr2Cqg1Ej3fcE',
  );
  
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: MaterialApp(
        title: 'Office Attendance App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}