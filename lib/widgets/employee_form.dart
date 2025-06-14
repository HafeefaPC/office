import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/office.dart';
import '../providers/attendance_provider.dart';

class EmployeeForm extends StatefulWidget {
  final Office office;

  const EmployeeForm({
    super.key,
    required this.office,
  });

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  String? _selectedEmployee;
  bool _isCheckedIn = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onEmployeeSelected(String? employeeEmail) {
    if (employeeEmail != null) {
      final employee = widget.office.employees.firstWhere(
        (emp) => emp.email == employeeEmail,
      );
      
      setState(() {
        _selectedEmployee = employeeEmail;
        _nameController.text = employee.name;
        _emailController.text = employee.email;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    
    final success = await provider.checkIn(
      _nameController.text.trim(),
      _emailController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _isCheckedIn = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully checked in to ${widget.office.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Check-in failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleCheckOut() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    
    final success = await provider.checkOut(_emailController.text.trim());

    if (success && mounted) {
      setState(() {
        _isCheckedIn = false;
        _selectedEmployee = null;
        _nameController.clear();
        _emailController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully checked out'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Check-out failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check ${_isCheckedIn ? 'Out from' : 'In to'} ${widget.office.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Employee Dropdown
              if (!_isCheckedIn) ...[
                DropdownButtonFormField<String>(
                  value: _selectedEmployee,
                  decoration: const InputDecoration(
                    labelText: 'Select Employee',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: widget.office.employees.map((employee) {
                    return DropdownMenuItem<String>(
                      value: employee.email,
                      child: Text('${employee.name} (${employee.email})'),
                    );
                  }).toList(),
                  onChanged: _onEmployeeSelected,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an employee';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Employee Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                readOnly: _selectedEmployee != null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter employee name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Employee Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                readOnly: _selectedEmployee != null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter employee email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: Consumer<AttendanceProvider>(
                  builder: (context, provider, child) {
                    return ElevatedButton(
                      onPressed: provider.isLoading
                          ? null
                          : (_isCheckedIn ? _handleCheckOut : _handleCheckIn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isCheckedIn ? 'Check Out' : 'Check In',
                              style: const TextStyle(fontSize: 16),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}