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
  String officeName = "";
  double? lat;
  double? lng;
  bool isLocationSet = false;
  double area = 100.0; // default value

  Future<void> _setOfficeLocation() async {
    final location = await LocationService().getCurrentLocation();
    setState(() {
      lat = location.latitude;
      lng = location.longitude;
      isLocationSet = true;
    });
  }
   Future<void> fetchOffices() async {
    final response = await Supabase.instance.client
        .from('offices')
        .select();

    if (response == null) {
      print('No response from Supabase.');
    } else {
      print('Offices: ${response}');
    }
  }
  Future<void> _saveToSupabase() async {
    if (_formKey.currentState!.validate() && lat != null && lng != null) {
      final response = await Supabase.instance.client
          .from('offices')
          .insert({
            'name': officeName,
            'area': area,
            'lat': lat,
            'lng': lng,
            'timestamp': DateTime.now().toIso8601String(),
          });

      if (response.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Office location saved!")),
        );
        setState(() {
          officeName = "";
          lat = null;
          lng = null;
          isLocationSet = false;
        });
        _formKey.currentState!.reset();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.error!.message}")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please set a valid location and office name."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Office Name"),
                onChanged: (value) => officeName = value,
                validator: (val) =>
                    val == null || val.isEmpty ? "Enter office name" : null,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Office Area (meters)",
                ),
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveToSupabase,
                  child: const Text("Save to Supabase"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
