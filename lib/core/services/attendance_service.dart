import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/office.dart';

class AttendanceService {
  final supabase = Supabase.instance.client;

  // Get current location with permissions
  Future<Position> getCurrentLocation() async {
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // Get current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Get all offices
  Future<List<Office>> getAllOffices() async {
    try {
      final response = await supabase
          .from('offices')
          .select('*')
          .order('name');

      return (response as List)
          .map((office) => Office.fromJson(office))
          .toList();
    } catch (e) {
      throw Exception('Failed to load offices: $e');
    }
  }

  // Check if employee is authorized for office
  Future<bool> isEmployeeAuthorized(int officeId, String employeeName, String employeeEmail) async {
    try {
      final response = await supabase
          .rpc('check_employee_authorization', params: {
        'office_id_param': officeId,
        'employee_name_param': employeeName,
        'employee_email_param': employeeEmail,
      });

      return response as bool;
    } catch (e) {
      throw Exception('Failed to verify employee authorization: $e');
    }
  }

  // Check in employee
  Future<void> checkIn({
    required int officeId,
    required String employeeName,
    required String employeeEmail,
    required double lat,
    required double lng,
  }) async {
    try {
      // First verify employee is authorized
      bool isAuthorized = await isEmployeeAuthorized(officeId, employeeName, employeeEmail);
      if (!isAuthorized) {
        throw Exception('Employee not authorized for this office');
      }

      // Check if employee is already checked in
      final existingCheckin = await supabase
          .from('checkins')
          .select('*')
          .eq('employee_email', employeeEmail)
          .isFilter('checkout_time', null)
          .maybeSingle();

      if (existingCheckin != null) {
        throw Exception('Employee is already checked in');
      }

      // Create new checkin record
      await supabase.from('checkins').insert({
        'office_id': officeId,
        'employee_name': employeeName,
        'employee_email': employeeEmail,
        'checkin_time': DateTime.now().toIso8601String(),
        'lat': lat,
        'lng': lng,
      });

      // Send email notification via Edge Function
      await _sendEmailNotification(
        officeId: officeId,
        employeeName: employeeName,
        employeeEmail: employeeEmail,
        action: 'checkin',
      );

    } catch (e) {
      throw Exception('Check-in failed: $e');
    }
  }

  // Check out employee
  Future<void> checkOut(String employeeEmail) async {
    try {
      // Find active checkin
      final checkin = await supabase
          .from('checkins')
          .select('*')
          .eq('employee_email', employeeEmail)
          .isFilter('checkout_time', null)
          .single();

      // Update checkin with checkout time
      await supabase
          .from('checkins')
          .update({
            'checkout_time': DateTime.now().toIso8601String(),
          })
          .eq('id', checkin['id']);

      // Send email notification
      await _sendEmailNotification(
        officeId: checkin['office_id'],
        employeeName: checkin['employee_name'],
        employeeEmail: employeeEmail,
        action: 'checkout',
      );

    } catch (e) {
      throw Exception('Check-out failed: $e');
    }
  }

  // Send email notification via Edge Function
  Future<void> _sendEmailNotification({
    required int officeId,
    required String employeeName,
    required String employeeEmail,
    required String action,
  }) async {
    try {
      await supabase.functions.invoke(
        'clever-service',
        body: {
          'action': 'send_email',
          'office_id': officeId,
          'employee_name': employeeName,
          'employee_email': employeeEmail,
          'checkin_action': action,
        },
      );
    } catch (e) {
      // Don't throw error for email failures, just log
      print('Email notification failed: $e');
    }
  }

  // Get employee's checkin history
  Future<List<Map<String, dynamic>>> getEmployeeHistory(String employeeEmail) async {
    try {
      final response = await supabase
          .from('admin_checkin_summary')
          .select('*')
          .eq('employee_email', employeeEmail)
          .order('checkin_time', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load history: $e');
    }
  }
}