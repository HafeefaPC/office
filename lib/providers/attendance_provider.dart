import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/attendance_service.dart';
import '../models/office.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  
  bool _isLoading = false;
  String? _error;
  Position? _currentPosition;
  List<Office> _offices = [];
  Office? _nearbyOffice;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  Position? get currentPosition => _currentPosition;
  List<Office> get offices => _offices;
  Office? get nearbyOffice => _nearbyOffice;
  
  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // Set error
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  // Get current location
  Future<void> getCurrentLocation() async {
    try {
      _setLoading(true);
      _setError(null);
      
      _currentPosition = await _attendanceService.getCurrentLocation();
      await _checkNearbyOffices();
      
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // Load all offices
  Future<void> loadOffices() async {
    try {
      _setLoading(true);
      _setError(null);
      
      _offices = await _attendanceService.getAllOffices();
      
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // Check for nearby offices
  Future<void> _checkNearbyOffices() async {
    if (_currentPosition == null || _offices.isEmpty) return;
    
    for (Office office in _offices) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        office.lat,
        office.lng,
      );
      
      // If within office area (using radius from area column)
      if (distance <= office.area) {
        _nearbyOffice = office;
        notifyListeners();
        return;
      }
    }
    
    _nearbyOffice = null;
    notifyListeners();
  }
  
  // Check in to office
  Future<bool> checkIn(String employeeName, String employeeEmail) async {
    if (_nearbyOffice == null || _currentPosition == null) {
      _setError('No nearby office found');
      return false;
    }
    
    try {
      _setLoading(true);
      _setError(null);
      
      await _attendanceService.checkIn(
        officeId: _nearbyOffice!.id,
        employeeName: employeeName,
        employeeEmail: employeeEmail,
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
      );
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Check out from office
  Future<bool> checkOut(String employeeEmail) async {
    try {
      _setLoading(true);
      _setError(null);
      
      await _attendanceService.checkOut(employeeEmail);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}