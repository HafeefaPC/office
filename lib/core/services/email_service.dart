// email_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  // Store verification codes temporarily (in production, use Redis or database)
  static final Map<String, VerificationData> _verificationCodes = {};
  
  Future<bool> sendVerificationEmail({
    required String fromEmail,
    required String toEmail,
    required String employeeName,
    required String officeName,
    required String verificationCode,
  }) async {
    try {
      // Store verification code with timestamp for validation
      _verificationCodes[toEmail] = VerificationData(
        code: verificationCode,
        timestamp: DateTime.now(),
        employeeName: employeeName,
        officeName: officeName,
      );

      // For demo purposes, we'll use Supabase Edge Functions or a simple notification
      // In production, you would integrate with actual email services
      
      // Option 1: Use Supabase Edge Functions for email sending
      final response = await _sendViaSupabaseFunction(
        fromEmail: fromEmail,
        toEmail: toEmail,
        employeeName: employeeName,
        officeName: officeName,
        verificationCode: verificationCode,
      );

      if (response) {
        return true;
      }

      // Option 2: Fallback to mock email for development
      return await _sendMockEmail(
        fromEmail: fromEmail,
        toEmail: toEmail,
        employeeName: employeeName,
        officeName: officeName,
        verificationCode: verificationCode,
      );

    } catch (error) {
      print('Email sending error: $error');
      return false;
    }
  }

  Future<bool> _sendViaSupabaseFunction({
    required String fromEmail,
    required String toEmail,
    required String employeeName,
    required String officeName,
    required String verificationCode,
  }) async {
    try {
      // Call Supabase Edge Function for email sending
      final response = await Supabase.instance.client.functions.invoke(
        'send-verification-email',
        body: {
          'fromEmail': fromEmail,
          'toEmail': toEmail,
          'employeeName': employeeName,
          'officeName': officeName,
          'verificationCode': verificationCode,
        },
      );

      return response.status == 200;
    } catch (error) {
      print('Supabase function error: $error');
      return false;
    }
  }

  Future<bool> _sendMockEmail({
    required String fromEmail,
    required String toEmail,
    required String employeeName,
    required String officeName,
    required String verificationCode,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Store in Supabase for admin to see (optional)
    try {
      await Supabase.instance.client
          .from('email_logs')
          .insert({
            'from_email': fromEmail,
            'to_email': toEmail,
            'employee_name': employeeName,
            'office_name': officeName,
            'verification_code': verificationCode,
            'sent_at': DateTime.now().toIso8601String(),
            'status': 'mock_sent',
          });
    } catch (e) {
      print('Failed to log email: $e');
    }
    
    // Print to console for development
    print('=== EMAIL SENT (DEVELOPMENT MODE) ===');
    print('From: $fromEmail ($officeName)');
    print('To: $toEmail ($employeeName)');
    print('Verification Code: $verificationCode');
    print('Time: ${DateTime.now()}');
    print('====================================');
    
    return true;
  }

  // Verify the code entered by user
  bool verifyCode({
    required String email,
    required String enteredCode,
  }) {
    final storedData = _verificationCodes[email];
    
    if (storedData == null) {
      return false;
    }
    
    // Check if code is expired (10 minutes)
    final now = DateTime.now();
    final timeDifference = now.difference(storedData.timestamp);
    
    if (timeDifference.inMinutes > 10) {
      _verificationCodes.remove(email);
      return false;
    }
    
    // Check if code matches
    if (storedData.code == enteredCode) {
      _verificationCodes.remove(email); // Remove after successful verification
      return true;
    }
    
    return false;
  }

  // Get stored verification data
  VerificationData? getVerificationData(String email) {
    return _verificationCodes[email];
  }

  // Clean up expired codes
  void cleanupExpiredCodes() {
    final now = DateTime.now();
    _verificationCodes.removeWhere((email, data) {
      return now.difference(data.timestamp).inMinutes > 10;
    });
  }
}

class VerificationData {
  final String code;
  final DateTime timestamp;
  final String employeeName;
  final String officeName;

  VerificationData({
    required this.code,
    required this.timestamp,
    required this.employeeName,
    required this.officeName,
  });
}