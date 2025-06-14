import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Replace with your actual Supabase credentials
  static const String supabaseUrl = 'https://dxkusdbluxpepeqpvmcw.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4a3VzZGJsdXhwZXBlcXB2bWN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3NTEyNzEsImV4cCI6MjA2NTMyNzI3MX0.ZEUSFKao3gAp4e3hWMsTUxZXWrCmZ4Yr2Cqg1Ej3fcE'; // Get this from Supabase Dashboard
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}