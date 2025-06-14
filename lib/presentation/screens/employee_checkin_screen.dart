import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/geofence_service.dart';
import '../../core/services/email_service.dart'; // You'll need to create this
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeCheckInScreen extends StatefulWidget {
  const EmployeeCheckInScreen({super.key});

  @override
  State<EmployeeCheckInScreen> createState() => _EmployeeCheckInScreenState();
}

class _EmployeeCheckInScreenState extends State<EmployeeCheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  
  String employeeName = "";
  String employeeEmail = "";
  String companyName = "";
  String verificationCode = "";
  String enteredCode = "";
  
  bool isInside = false;
  bool isCodeSent = false;
  bool isVerified = false;
  bool isLoading = false;
  
  Map<String, dynamic>? currentOffice;
  String? activeSessionId;
  
  // Timer for work duration
  Timer? workTimer;
  Duration workDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    workTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadOffice() async {
    final response = await Supabase.instance.client
        .from("offices")
        .select()
        .eq("name", companyName)
        .maybeSingle();

    if (response != null) {
      setState(() {
        currentOffice = response;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Company not found.")),
      );
    }
  }

  bool _isEmployeeAuthorized() {
    if (currentOffice == null) return false;
    
    final employees = currentOffice!['employees'] as List<dynamic>?;
    if (employees == null) return false;
    
    return employees.any((emp) => 
      emp['name'].toString().toLowerCase() == employeeName.toLowerCase() &&
      emp['email'].toString().toLowerCase() == employeeEmail.toLowerCase()
    );
  }

  String _generateVerificationCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString(); // 4-digit code
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      await _loadOffice();
      
      if (currentOffice == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      if (!_isEmployeeAuthorized()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Employee not authorized for this office. Please contact admin."),
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Generate verification code
      verificationCode = _generateVerificationCode();
      
      // Send email (you'll need to implement EmailService)
      final emailSent = await EmailService().sendVerificationEmail(
        fromEmail: currentOffice!['office_email'],
        toEmail: employeeEmail,
        employeeName: employeeName,
        officeName: companyName,
        verificationCode: verificationCode,
      );

      if (emailSent) {
        setState(() {
          isCodeSent = true;
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification code sent to your email!"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to send verification code. Please try again."),
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $error")),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _verifyCodeAndCheckIn() async {
    // Use EmailService to verify the code
    final isValidCode = EmailService().verifyCode(
      email: employeeEmail,
      enteredCode: enteredCode,
    );

    if (!isValidCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid or expired verification code. Please try again."),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final location = await LocationService().getCurrentLocation();
      final officeLat = double.tryParse(currentOffice!['lat'].toString());
      final officeLng = double.tryParse(currentOffice!['lng'].toString());
      final area = double.tryParse(currentOffice!['area'].toString()) ?? 100.0;

      if (officeLat == null || officeLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid office location data.")),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      final isNowInside = await GeofenceService().isWithinGeofence(
        location.latitude,
        location.longitude,
        officeLat,
        officeLng,
        radiusInMeters: area,
      );

      if (!isNowInside) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You are not within the office premises. Please get closer to the office."),
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      final now = DateTime.now().toIso8601String();

      // Check if already checked in
      final existingCheckin = await Supabase.instance.client
          .from("checkins")
          .select()
          .eq("employee_email", employeeEmail)
          .eq("office_id", currentOffice!['id'])
          .filter('checkout_time', 'is', null)
          .maybeSingle();

      if (existingCheckin != null) {
        activeSessionId = existingCheckin['id'];
        // Calculate existing work duration
        final checkinTime = DateTime.parse(existingCheckin['checkin_time']);
        workDuration = DateTime.now().difference(checkinTime);
      } else {
        // Insert new check-in
        final response = await Supabase.instance.client
            .from("checkins")
            .insert({
              "employee_name": employeeName,
              "employee_email": employeeEmail,
              "office_id": currentOffice!['id'],
              "checkin_time": now,
              "lat": location.latitude,
              "lng": location.longitude,
            })
            .select()
            .single();

        activeSessionId = response['id'];
        workDuration = Duration.zero;
        
        NotificationService().showNotification(
          "Checked In Successfully",
          "$employeeName checked in to ${currentOffice!['name']}.",
        );
      }

      setState(() {
        isInside = true;
        isVerified = true;
        isLoading = false;
      });
      
      _startWorkTimer();

    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during check-in: $error")),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  void _startWorkTimer() {
    workTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        workDuration = workDuration + const Duration(seconds: 1);
      });
    });
  }

  Future<void> _checkOut() async {
    if (activeSessionId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final now = DateTime.now().toIso8601String();
      
      await Supabase.instance.client
          .from("checkins")
          .update({"checkout_time": now})
          .eq("id", activeSessionId!);

      NotificationService().showNotification(
        "Checked Out Successfully",
        "$employeeName checked out from ${currentOffice!['name']}.",
      );

      setState(() {
        isInside = false;
        isVerified = false;
        isCodeSent = false;
        isLoading = false;
        workDuration = Duration.zero;
      });
      
      workTimer?.cancel();
      activeSessionId = null;
      
      // Reset form
      _formKey.currentState!.reset();
      _codeController.clear();
      employeeName = "";
      employeeEmail = "";
      companyName = "";
      verificationCode = "";
      enteredCode = "";

    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during check-out: $error")),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Employee Check-In"),
        backgroundColor: isInside ? Colors.green : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isInside && isVerified) ...[
                // Work Status Card
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.work,
                          size: 50,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "You're at work!",
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Office: ${currentOffice!['name']}",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          "Employee: $employeeName",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        // Work Timer
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Work Duration",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _formatDuration(workDuration),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : _checkOut,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.logout),
                          label: const Text("Check Out"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Check-in Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Company Name",
                          prefixIcon: Icon(Icons.business),
                        ),
                        onChanged: (val) => companyName = val,
                        enabled: !isCodeSent,
                        validator: (val) =>
                            val == null || val.isEmpty ? "Enter company name" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Your Name",
                          prefixIcon: Icon(Icons.person),
                        ),
                        onChanged: (val) => employeeName = val,
                        enabled: !isCodeSent,
                        validator: (val) =>
                            val == null || val.isEmpty ? "Enter your name" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Your Email",
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (val) => employeeEmail = val,
                        enabled: !isCodeSent,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Enter your email";
                          if (!val.contains('@')) return "Enter valid email";
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      if (!isCodeSent) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _sendVerificationCode,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            label: const Text("Send Verification Code"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Verification Code Input
                        TextFormField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: "Enter Verification Code",
                            prefixIcon: Icon(Icons.lock),
                            helperText: "Check your email for the 4-digit code",
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          onChanged: (val) => enteredCode = val,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _verifyCodeAndCheckIn,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle),
                            label: const Text("Verify & Check In"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isCodeSent = false;
                              verificationCode = "";
                              enteredCode = "";
                              _codeController.clear();
                            });
                          },
                          child: const Text("Resend Code"),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 30),
              
              // Status Indicator
              Card(
                color: isInside ? Colors.green.shade50 : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isInside ? Icons.check_circle : Icons.location_off,
                        color: isInside ? Colors.green : Colors.grey,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isInside ? "You're inside the office" : "You're outside the office",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isInside ? Colors.green.shade800 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}