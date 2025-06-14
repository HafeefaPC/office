import 'package:flutter/material.dart';
import '../../core/services/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeFormKey = GlobalKey<FormState>();
  String officeName = "";
  String officeEmail = "";
  double? lat;
  double? lng;
  bool isLocationSet = false;
  double area = 100.0;
  
  // Employee management
  List<Map<String, String>> employees = [];
  String newEmployeeName = "";
  String newEmployeeEmail = "";
  bool showEmployeeForm = false;

  Future<void> _setOfficeLocation() async {
    final location = await LocationService().getCurrentLocation();
    setState(() {
      lat = location.latitude;
      lng = location.longitude;
      isLocationSet = true;
    });
  }

  void _addEmployee() {
    if (_employeeFormKey.currentState!.validate()) {
      setState(() {
        employees.add({
          'name': newEmployeeName,
          'email': newEmployeeEmail,
        });
        newEmployeeName = "";
        newEmployeeEmail = "";
        showEmployeeForm = false;
      });
      _employeeFormKey.currentState!.reset();
    }
  }

  void _removeEmployee(int index) {
    setState(() {
      employees.removeAt(index);
    });
  }

  Future<void> _saveToSupabase() async {
    if (_formKey.currentState!.validate() && 
        lat != null && 
        lng != null && 
        employees.isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('offices')
            .insert({
              'name': officeName,
              'office_email': officeEmail,
              'area': area,
              'lat': lat,
              'lng': lng,
              'employees': employees, // Store as JSON array
              'timestamp': DateTime.now().toIso8601String(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Office location and employees saved!")),
        );
        setState(() {
          officeName = "";
          officeEmail = "";
          lat = null;
          lng = null;
          isLocationSet = false;
          employees.clear();
        });
        _formKey.currentState!.reset();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $error")),
        );
      }
    } else {
      String message = "Please ensure all fields are filled: ";
      List<String> missing = [];
      if (officeName.isEmpty) missing.add("office name");
      if (officeEmail.isEmpty) missing.add("office email");
      if (!isLocationSet) missing.add("location");
      if (employees.isEmpty) missing.add("at least one employee");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message + missing.join(", ")),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCheckIns() async {
    final data = await Supabase.instance.client
        .from('checkins')
        .select('employee_name, employee_email, checkin_time, checkout_time, office_id')
        .order('checkin_time', ascending: false);

    return data;
  }

  String _calculateDuration(String checkin, String? checkout) {
    final inTime = DateTime.parse(checkin);
    final outTime = checkout != null ? DateTime.parse(checkout) : DateTime.now();
    final duration = outTime.difference(inTime);
    return "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Office Details Section
                const Text(
                  "Office Details",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Office Name"),
                  onChanged: (value) => officeName = value,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter office name" : null,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Office Email"),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => officeEmail = value,
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Enter office email";
                    if (!val.contains('@')) return "Enter valid email";
                    return null;
                  },
                ),
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: "Office Area (meters)"),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    area = double.tryParse(value) ?? 100.0;
                  },
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter area in meters" : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text("Set Office Location"),
                  onPressed: _setOfficeLocation,
                ),
                if (isLocationSet)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      "Location set to: (Lat: ${lat!.toStringAsFixed(5)}, Lng: ${lng!.toStringAsFixed(5)})",
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                
                const SizedBox(height: 30),
                
                // Employee Management Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Employees",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add Employee"),
                      onPressed: () {
                        setState(() {
                          showEmployeeForm = !showEmployeeForm;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Add Employee Form
                if (showEmployeeForm)
                  Form(
                    key: _employeeFormKey,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              decoration: const InputDecoration(labelText: "Employee Name"),
                              onChanged: (value) => newEmployeeName = value,
                              validator: (val) =>
                                  val == null || val.isEmpty ? "Enter employee name" : null,
                            ),
                            TextFormField(
                              decoration: const InputDecoration(labelText: "Employee Email"),
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (value) => newEmployeeEmail = value,
                              validator: (val) {
                                if (val == null || val.isEmpty) return "Enter employee email";
                                if (!val.contains('@')) return "Enter valid email";
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _addEmployee,
                                    child: const Text("Add Employee"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        showEmployeeForm = false;
                                        newEmployeeName = "";
                                        newEmployeeEmail = "";
                                      });
                                    },
                                    child: const Text("Cancel"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Employee List
                if (employees.isNotEmpty)
                  Column(
                    children: employees.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, String> employee = entry.value;
                      return Card(
                        child: ListTile(
                          title: Text(employee['name']!),
                          subtitle: Text(employee['email']!),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeEmployee(index),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                
                const SizedBox(height: 30),
                
                // Recent Check-ins Section
                const Text(
                  "Recent Employee Check-ins",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchCheckIns(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Text("Error: ${snapshot.error}");
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text("No check-ins yet.");
                    }

                    final data = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final item = data[index];
                        final duration = _calculateDuration(
                            item['checkin_time'], item['checkout_time']);
                        return Card(
                          child: ListTile(
                            title: Text(item['employee_name']),
                            subtitle: Text(
                                "Email: ${item['employee_email']}\nIn: ${item['checkin_time']}\nOut: ${item['checkout_time'] ?? "Currently Inside"}\nDuration: $duration"),
                          ),
                        );
                      },
                    );
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveToSupabase,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("Save Office & Employees"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}