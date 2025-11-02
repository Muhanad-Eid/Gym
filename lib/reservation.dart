import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationPage extends StatefulWidget {
  const ReservationPage({Key? key}) : super(key: key);

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final supabase = Supabase.instance.client;
  
  DateTime? selectedDate;
  String? selectedTime;
  Map<String, dynamic>? selectedTrainer;
  int? selectedDuration = 60;
  bool isLoading = false;
  bool isAdmin = false; // Set this based on your user role logic
  List<Map<String, dynamic>> trainers = [];
  List<String> availableTimes = [];

  final List<int> durations = [30, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadTrainers();
  }

  // Check if user is admin
  Future<void> _checkAdminStatus() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('user_roles')
            .select('role')
            .eq('user_id', user.id)
            .single();
        
        setState(() {
          isAdmin = response['role'] == 'admin';
        });
      }
    } catch (e) {
      // User doesn't have a role or error occurred
      setState(() => isAdmin = false);
    }
  }

  Future<void> _loadTrainers() async {
    try {
      setState(() => isLoading = true);
      
      final response = await supabase
          .from('trainers')
          .select('id, name, specialty, avatar_url, hourly_rate, is_active')
          .eq('is_active', true)
          .order('name');

      setState(() {
        trainers = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load trainers: $e');
    }
  }

  void _generateTimeSlots() {
    availableTimes.clear();
    for (int hour = 8; hour <= 20; hour++) {
      availableTimes.add('${hour.toString().padLeft(2, '0')}:00');
      if (hour < 20) {
        availableTimes.add('${hour.toString().padLeft(2, '0')}:30');
      }
    }
  }

  Future<List<String>> _getBookedSlots(DateTime date, dynamic trainerId) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('reservations')
          .select('time_slot, duration')
          .eq('trainer_id', trainerId.toString())
          .gte('date', startOfDay.toIso8601String())
          .lt('date', endOfDay.toIso8601String())
          .eq('status', 'confirmed');

      return List<String>.from(response.map((r) => r['time_slot']));
    } catch (e) {
      print('Error loading booked slots: $e');
      return [];
    }
  }

  void _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
        selectedTime = null;
      });
      _generateTimeSlots();
    }
  }

  Future<void> _confirmReservation() async {
    if (selectedDate == null || selectedTime == null || selectedTrainer == null) {
      _showError('Please select all options before confirming.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showError('Please log in to make a reservation.');
        setState(() => isLoading = false);
        return;
      }

      final bookedSlots = await _getBookedSlots(
        selectedDate!,
        selectedTrainer!['id'],
      );

      if (bookedSlots.contains(selectedTime)) {
        _showError('This time slot is no longer available. Please select another.');
        setState(() => isLoading = false);
        return;
      }

      final reservation = {
        'user_id': user.id,
        'trainer_id': selectedTrainer!['id'],
        'date': selectedDate!.toIso8601String(),
        'time_slot': selectedTime,
        'duration': selectedDuration,
        'status': 'confirmed',
        'total_price': (selectedTrainer!['hourly_rate'] * selectedDuration! / 60).toDouble(),
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('reservations').insert(reservation);

      setState(() => isLoading = false);

      if (mounted) {
        // Save values before resetting
        final bookedDate = selectedDate!;
        final bookedTime = selectedTime!;
        
        // Reset form first
        setState(() {
          selectedDate = null;
          selectedTime = null;
          selectedTrainer = null;
          selectedDuration = 60;
        });
        
        // Then show success with saved values
        _showSuccess(bookedDate, bookedTime);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to create reservation: $e');
    }
  }

  void _showAddTrainerDialog() {
    final nameController = TextEditingController();
    final specialtyController = TextEditingController();
    final rateController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Add New Trainer'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Trainer Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: specialtyController,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fitness_center),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Specialty is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: rateController,
                  decoration: const InputDecoration(
                    labelText: 'Hourly Rate (\$)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Rate is required';
                    if (double.tryParse(value!) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _addTrainer(
                  nameController.text,
                  specialtyController.text,
                  double.parse(rateController.text),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTrainer(String name, String specialty, double rate) async {
    try {
      setState(() => isLoading = true);

      await supabase.from('trainers').insert({
        'name': name,
        'specialty': specialty,
        'hourly_rate': rate,
        'is_active': true,
      });

      await _loadTrainers();
      _showSuccessMessage('Trainer added successfully!');
    } catch (e) {
      _showError('Failed to add trainer: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showEditTrainerDialog(Map<String, dynamic> trainer) {
    final nameController = TextEditingController(text: trainer['name']);
    final specialtyController = TextEditingController(text: trainer['specialty']);
    final rateController = TextEditingController(
      text: trainer['hourly_rate'].toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Edit Trainer'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Trainer Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: specialtyController,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fitness_center),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Specialty is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: rateController,
                  decoration: const InputDecoration(
                    labelText: 'Hourly Rate (\$)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Rate is required';
                    if (double.tryParse(value!) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _updateTrainer(
                  trainer['id'],
                  nameController.text,
                  specialtyController.text,
                  double.parse(rateController.text),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTrainer(
    dynamic id,
    String name,
    String specialty,
    double rate,
  ) async {
    try {
      setState(() => isLoading = true);

      final response = await supabase.from('trainers').update({
        'name': name,
        'specialty': specialty,
        'hourly_rate': rate,
      }).eq('id', id.toString());

      print('Update response: $response');

      await _loadTrainers();
      
      if (mounted) {
        _showSuccessMessage('Trainer updated successfully!');
      }
    } catch (e) {
      print('Update error: $e');
      if (mounted) {
        _showError('Failed to update trainer: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> trainer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Trainer'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${trainer['name']}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTrainer(trainer['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrainer(dynamic id) async {
    try {
      setState(() => isLoading = true);

      // Soft delete by setting is_active to false
      final response = await supabase.from('trainers').update({
        'is_active': false,
      }).eq('id', id.toString());

      print('Delete response: $response');

      await _loadTrainers();
      
      if (mounted) {
        _showSuccessMessage('Trainer deleted successfully!');
      }
    } catch (e) {
      print('Delete error: $e');
      if (mounted) {
        _showError('Failed to delete trainer: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(DateTime date, String time) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Text(
          'Your reservation has been confirmed for ${DateFormat('EEEE, MMM d').format(date)} at $time',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Book a Session', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddTrainerDialog,
              tooltip: 'Add Trainer',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Selection Card
                  _buildSectionTitle('Select Date'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_today, color: Colors.deepPurple),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedDate == null
                                        ? 'Choose a date'
                                        : DateFormat('EEEE, MMMM d, yyyy').format(selectedDate!),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Trainer Selection
                  _buildSectionTitle('Choose Your Trainer'),
                  const SizedBox(height: 8),
                  if (trainers.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.person_off, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('No trainers available'),
                              if (isAdmin) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _showAddTrainerDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Trainer'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...trainers.map((trainer) => _buildTrainerCard(trainer)).toList(),
                  const SizedBox(height: 24),

                  // Duration Selection
                  if (selectedTrainer != null) ...[
                    _buildSectionTitle('Session Duration'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: durations.map((duration) {
                        final isSelected = selectedDuration == duration;
                        return ChoiceChip(
                          label: Text('$duration min'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => selectedDuration = duration);
                          },
                          selectedColor: Colors.deepPurple,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Time Selection
                  if (selectedDate != null && selectedTrainer != null) ...[
                    _buildSectionTitle('Select Time'),
                    const SizedBox(height: 8),
                    FutureBuilder<List<String>>(
                      future: _getBookedSlots(selectedDate!, selectedTrainer!['id']),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final bookedSlots = snapshot.data!;
                        _generateTimeSlots();

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableTimes.map((time) {
                            final isBooked = bookedSlots.contains(time);
                            final isSelected = selectedTime == time;

                            return InkWell(
                              onTap: isBooked ? null : () => setState(() => selectedTime = time),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isBooked
                                      ? Colors.grey[200]
                                      : isSelected
                                          ? Colors.deepPurple
                                          : Colors.white,
                                  border: Border.all(
                                    color: isBooked
                                        ? Colors.grey[300]!
                                        : isSelected
                                            ? Colors.deepPurple
                                            : Colors.grey[300]!,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    color: isBooked
                                        ? Colors.grey[400]
                                        : isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    decoration: isBooked ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Price Summary
                  if (selectedTrainer != null && selectedDuration != null) ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Price:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${(selectedTrainer!['hourly_rate'] * selectedDuration! / 60).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (selectedDate != null &&
                              selectedTime != null &&
                              selectedTrainer != null)
                          ? _confirmReservation
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Reservation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTrainerCard(Map<String, dynamic> trainer) {
    final isSelected = selectedTrainer?['id'] == trainer['id'];

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => selectedTrainer = trainer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                backgroundImage: trainer['avatar_url'] != null
                    ? NetworkImage(trainer['avatar_url'])
                    : null,
                child: trainer['avatar_url'] == null
                    ? Text(
                        trainer['name'][0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trainer['specialty'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${trainer['hourly_rate']}/hour',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.deepPurple, size: 28)
              else if (isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditTrainerDialog(trainer);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(trainer);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}