import 'package:flutter/material.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/geofence_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeCheckInScreen extends StatefulWidget {
  const EmployeeCheckInScreen({super.key});

  @override
  State<EmployeeCheckInScreen> createState() => _EmployeeCheckInScreenState();
}

class _EmployeeCheckInScreenState extends State<EmployeeCheckInScreen> {
  String employeeName = "";
  bool isInside = false;
  Map<String, dynamic>? currentOffice;
  String? activeSessionId;

  @override
  void initState() {
    super.initState();
    _loadOffice();
  }

  Future<void> _loadOffice() async {
    final response = await Supabase.instance.client
        .from("offices")
        .select()
        .limit(1)
        .maybeSingle();

    if (response != null) {
      setState(() {
        currentOffice = response;
      });
    }
  }

  Future<void> _checkGeofence() async {
    if (employeeName.isEmpty || currentOffice == null) return;

    final location = await LocationService().getCurrentLocation();
    final officeLat = currentOffice!['lat'];
    final officeLng = currentOffice!['lng'];
    final area = currentOffice!['area'] ?? 100.0;

    final isNowInside = await GeofenceService().isWithinGeofence(
      location.latitude,
      location.longitude,
      officeLat,
      officeLng,
      radiusInMeters: area,
    );

    final now = DateTime.now().toIso8601String();

    if (isNowInside && !isInside) {
      // Check-in
      final response = await Supabase.instance.client
          .from("checkins")
          .insert({
            "employee_name": employeeName,
            "office_id": currentOffice!['id'],
            "checkin": now,
            "lat": location.latitude,
            "lng": location.longitude,
          })
          .select()
          .single();

      activeSessionId = response['id'];
      NotificationService().showNotification("Checked In", "$employeeName entered office.");
    } else if (!isNowInside && isInside && activeSessionId != null) {
  final sessionId = activeSessionId!; // local non-nullable variable
  await Supabase.instance.client
      .from("checkins")
      .update({"checkout": now})
      .eq("id", sessionId);

      NotificationService().showNotification("Checked Out", "$employeeName left office.");
      activeSessionId = null;
    }

    setState(() {
      isInside = isNowInside;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Employee Check-In")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Your Name"),
              onChanged: (val) => employeeName = val,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkGeofence,
              child: const Text("Check My Status"),
            ),
            const SizedBox(height: 10),
            Text(isInside ? "You're inside the office" : "You're outside"),
          ],
        ),
      ),
    );
  }
}
