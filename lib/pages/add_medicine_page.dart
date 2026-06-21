import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: '');
  final _dosageController = TextEditingController(text: '500');
  String _selectedType = 'Tablet';
  String _selectedUnit = 'mg';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  int _stockCount = 30;
  final int _refillAlert = 10;
  bool _isSaving = false;
  String _selectedMealInstruction = 'Before Breakfast';

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatted = '${_selectedTime.hourOfPeriod.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} ${_selectedTime.period == DayPeriod.am ? 'AM' : 'PM'}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B72D0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Medicine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medicine Name
                _buildLabel('Medicine Name'),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F2B48),
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF8A9AAD),
                    ),
                    hintText: 'e.g. Metformin 500mg',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8A9AAD),
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2B72D0), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2B72D0), width: 2.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter medicine name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Type selector
                _buildLabel('Type'),
                Row(
                  children: [
                    _buildTypeChip('Tablet', Icons.medication_rounded),
                    const SizedBox(width: 12),
                    _buildTypeChip('Capsule', Icons.lens_blur_rounded),
                    const SizedBox(width: 12),
                    _buildTypeChip('Liquid', Icons.opacity_rounded),
                  ],
                ),
                const SizedBox(height: 24),

                // Dosage
                _buildLabel('Dosage'),
                Row(
                  children: [
                    // Dosage numeric input
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _dosageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F2B48),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter dose';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Unit selector dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedUnit,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8A9AAD)),
                            style: const TextStyle(
                              color: Color(0xFF0F2B48),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            items: <String>['mg', 'g', 'ml', 'pills'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedUnit = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Reminder Time
                _buildLabel('Reminder Time'),
                GestureDetector(
                  onTap: () => _selectTime(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F9FD),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8F2FF), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: Color(0xFF2B72D0), size: 24),
                        const SizedBox(width: 16),
                        Text(
                          timeFormatted,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F2B48),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A9AAD), size: 24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Meal Instruction
                _buildLabel('Meal Instruction'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8F2FF), width: 1.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMealInstruction,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8A9AAD)),
                      style: const TextStyle(
                        color: Color(0xFF0F2B48),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      isExpanded: true,
                      items: <String>[
                        'Before Breakfast',
                        'After Breakfast',
                        'Before Lunch',
                        'After Lunch',
                        'Before Dinner',
                        'After Dinner'
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedMealInstruction = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stock Count
                _buildLabel('Stock Count'),
                GestureDetector(
                  onTap: () async {
                    // Quick modal or simply prompt update
                    final count = await _showNumberPickerDialog('Stock Count', _stockCount);
                    if (count != null) {
                      setState(() {
                        _stockCount = count;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F9FD),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8F2FF), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: Color(0xFF2B72D0), size: 24),
                        const SizedBox(width: 16),
                        Text(
                          '$_stockCount pills',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F2B48),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Refill at $_refillAlert',
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF8A9AAD),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isSaving = true;
                              });
                              try {
                                final dosageVal = double.tryParse(_dosageController.text.trim()) ?? 0.0;
                                 await SupabaseService.addMedication(
                                  name: _nameController.text.trim(),
                                  type: _selectedType,
                                  dosage: dosageVal,
                                  unit: _selectedUnit,
                                  reminderTime: timeFormatted,
                                  stockCount: _stockCount,
                                  refillAlert: _refillAlert,
                                  mealInstruction: _selectedMealInstruction,
                                );
                                
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Medicine saved successfully')),
                                );
                                Navigator.of(context).pop(true);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save medicine: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              } finally {
                                if (context.mounted) {
                                  setState(() {
                                    _isSaving = false;
                                  });
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B72D0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Save Medicine',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8A9AAD),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    final isSelected = _selectedType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = label;
          });
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2B72D0) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? const Color(0xFF2B72D0) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF8A9AAD),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF0F2B48),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _showNumberPickerDialog(String title, int currentValue) async {
    int tempValue = currentValue;
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (tempValue > 1) {
                        setState(() => tempValue--);
                      }
                    },
                  ),
                  Text(
                    '$tempValue',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() => tempValue++);
                    },
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(tempValue),
            ),
          ],
        );
      },
    );
  }
}
