// email_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
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

      print('Attempting to send email via Supabase function...');
      
      // Try Supabase Edge Function first
      final response = await _sendViaSupabaseFunction(
        fromEmail: fromEmail,
        toEmail: toEmail,
        employeeName: employeeName,
        officeName: officeName,
        verificationCode: verificationCode,
      );

      if (response) {
        print('Email sent successfully via Supabase function');
        return true;
      }

      print('Supabase function failed, using mock email fallback...');
      
      // Fallback to mock email for development
      return await _sendMockEmail(
        fromEmail: fromEmail,
        toEmail: toEmail,
        employeeName: employeeName,
        officeName: officeName,
        verificationCode: verificationCode,
      );

    } catch (error) {
      print('Email sending error: $error');
      
      // Always try mock email as final fallback
      return await _sendMockEmail(
        fromEmail: fromEmail,
        toEmail: toEmail,
        employeeName: employeeName,
        officeName: officeName,
        verificationCode: verificationCode,
      );
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
      print('Calling Supabase Edge Function...');
      
      // Add timeout to prevent hanging
      final response = await Supabase.instance.client.functions.invoke(
        'send-verification-email',
        body: {
          'fromEmail': fromEmail,
          'toEmail': toEmail,
          'employeeName': employeeName,
          'officeName': officeName,
          'verificationCode': verificationCode,
        },
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Supabase function timeout after 10 seconds');
          throw Exception('Function call timeout');
        },
      );

      print('Supabase function response status: ${response.status}');
      print('Supabase function response data: ${response.data}');

      if (response.status == 200) {
        // Check if the response indicates success
        if (response.data is Map && response.data['success'] == true) {
          return true;
        } else {
          print('Function returned 200 but success was false: ${response.data}');
          return false;
        }
      } else {
        print('Supabase function returned non-200 status: ${response.status}');
        return false;
      }
      
    } catch (error) {
      print('Supabase function error: $error');
      
      // Enhanced error detection
      final errorString = error.toString().toLowerCase();
      
      if (errorString.contains('cors')) {
        print('CORS error detected. Solutions:');
        print('1. Redeploy the edge function: supabase functions deploy send-verification-email');
        print('2. Check if function is properly deployed: supabase functions list');
        print('3. Verify CORS headers in the function code');
      } else if (errorString.contains('failed to fetch') || errorString.contains('network')) {
        print('Network error detected. This might be due to:');
        print('1. Edge function not deployed or not responding');
        print('2. Network connectivity issue');
        print('3. Supabase service temporary unavailability');
      } else if (errorString.contains('timeout')) {
        print('Function timeout detected. The edge function may be taking too long to respond');
      }
      
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
    print('Using mock email service...');
    
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
            'notes': 'Sent via mock email service due to edge function failure',
          });
          
      print('Email logged to database successfully');
          
    } catch (e) {
      print('Failed to log email to database: $e');
      // Don't fail the whole operation if logging fails
    }
    
    // Print to console for development
    print('=== EMAIL SENT (DEVELOPMENT MODE) ===');
    print('From: $fromEmail ($officeName)');
    print('To: $toEmail ($employeeName)');
    print('Subject: Verification Code for $officeName');
    print('Verification Code: $verificationCode');
    print('Time: ${DateTime.now()}');
    print('Note: This is a mock email. In production, integrate with a real email service.');
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
      print('No verification data found for email: $email');
      return false;
    }
    
    // Check if code is expired (10 minutes)
    final now = DateTime.now();
    final timeDifference = now.difference(storedData.timestamp);
    
    if (timeDifference.inMinutes > 10) {
      print('Verification code expired for email: $email');
      _verificationCodes.remove(email);
      return false;
    }
    
    // Check if code matches
    if (storedData.code == enteredCode) {
      print('Verification code verified successfully for email: $email');
      _verificationCodes.remove(email); // Remove after successful verification
      return true;
    }
    
    print('Verification code mismatch for email: $email');
    return false;
  }

  // Get stored verification data
  VerificationData? getVerificationData(String email) {
    return _verificationCodes[email];
  }

  // Clean up expired codes
  void cleanupExpiredCodes() {
    final now = DateTime.now();
    final expiredEmails = <String>[];
    
    _verificationCodes.forEach((email, data) {
      if (now.difference(data.timestamp).inMinutes > 10) {
        expiredEmails.add(email);
      }
    });
    
    for (final email in expiredEmails) {
      _verificationCodes.remove(email);
    }
    
    if (expiredEmails.isNotEmpty) {
      print('Cleaned up ${expiredEmails.length} expired verification codes');
    }
  }

  // Get debug info about stored codes
  Map<String, dynamic> getDebugInfo() {
    return {
      'stored_codes_count': _verificationCodes.length,
      'stored_emails': _verificationCodes.keys.toList(),
    };
  }

  // Test function connectivity
  Future<bool> testFunctionConnectivity() async {
    try {
      print('Testing edge function connectivity...');
      
      final response = await Supabase.instance.client.functions.invoke(
        'send-verification-email',
        body: {
          'fromEmail': 'test@example.com',
          'toEmail': 'test@example.com',
          'employeeName': 'Test Employee',
          'officeName': 'Test Office',
          'verificationCode': '0000',
        },
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      print('Test response status: ${response.status}');
      print('Test response data: ${response.data}');
      
      return response.status == 200;
      
    } catch (error) {
      print('Function connectivity test failed: $error');
      return false;
    }
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

  // Helper method to check if expired
  bool get isExpired {
    final now = DateTime.now();
    return now.difference(timestamp).inMinutes > 10;
  }

  // Helper method to get time remaining
  int get minutesRemaining {
    final now = DateTime.now();
    final elapsed = now.difference(timestamp).inMinutes;
    return math.max(0, 10 - elapsed);
  }
}