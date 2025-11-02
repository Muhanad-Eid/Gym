import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class GymClass {
  final String id;
  final String name;
  final String instructor;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final int enrolled;
  final String level;
  final String category;
  final String room;
  final String colorHex;

  GymClass({
    required this.id,
    required this.name,
    required this.instructor,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.enrolled,
    required this.level,
    required this.category,
    required this.room,
    required this.colorHex,
  });

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  int get duration => endTime.difference(startTime).inMinutes;
  double get occupancyRate {
    if (capacity == 0) return 0.0;
    return (enrolled / capacity) * 100;
  }

  factory GymClass.fromJson(Map<String, dynamic> json) {
    return GymClass(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      instructor: json['instructor'] ?? '',
      description: json['description'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      capacity: json['capacity'] ?? 0,
      enrolled: json['enrolled'] ?? 0,
      level: json['level'] ?? 'Beginner',
      category: json['category'] ?? 'General',
      room: json['room'] ?? '',
      colorHex: json['color_hex'] ?? '#9C27B0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'instructor': instructor,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'capacity': capacity,
      'enrolled': enrolled,
      'level': level,
      'category': category,
      'room': room,
      'color_hex': colorHex,
    };
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({Key? key}) : super(key: key);

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final supabase = Supabase.instance.client;
  String selectedView = 'week';
  DateTime selectedDate = DateTime.now();
  String selectedFilter = 'All';
  List<GymClass> classes = [];
  bool isLoading = true;

  final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> categories = ['All', 'Cardio', 'Strength', 'Yoga', 'Pilates', 'Cycling', 'Dance'];

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  Future<void> fetchClasses() async {
    setState(() => isLoading = true);
    
    try {
      final response = await supabase
          .from('gym_classes')
          .select()
          .order('start_time', ascending: true);

      setState(() {
        classes = (response as List)
            .map((json) => GymClass.fromJson(json))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading classes: $e')),
        );
      }
    }
  }

  List<GymClass> get filteredClasses {
    if (selectedFilter == 'All') {
      return classes;
    }
    return classes.where((c) => c.category == selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Schedule'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchClasses,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => selectedDate = date);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.view_module),
            onSelected: (value) => setState(() => selectedView = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'week', child: Text('Week View')),
              const PopupMenuItem(value: 'day', child: Text('Day View')),
              const PopupMenuItem(value: 'list', child: Text('List View')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Filter chips
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = selectedFilter == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => selectedFilter = category);
                      },
                      backgroundColor: Colors.white,
                      selectedColor: Colors.deepPurple.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.deepPurple : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Content
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : classes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No classes available',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : selectedView == 'list'
                          ? _buildListView()
                          : selectedView == 'day'
                              ? _buildDayView()
                              : _buildWeekView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddClassDialog(),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
    );
  }

  Widget _buildWeekView() {
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(7, (index) {
            final dayDate = startOfWeek.add(Duration(days: index));
            final dayClasses = filteredClasses.where((c) {
              return c.startTime.year == dayDate.year &&
                  c.startTime.month == dayDate.month &&
                  c.startTime.day == dayDate.day;
            }).toList();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          weekDays[index],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM').format(dayDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${dayClasses.length} classes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dayClasses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No classes scheduled',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ...dayClasses.map((gymClass) => _buildClassCard(gymClass)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDayView() {
    final dayClasses = filteredClasses.where((c) {
      return c.startTime.day == selectedDate.day &&
          c.startTime.month == selectedDate.month &&
          c.startTime.year == selectedDate.year;
    }).toList();

    dayClasses.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.deepPurple.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    selectedDate = selectedDate.subtract(const Duration(days: 1));
                  });
                },
              ),
              Text(
                DateFormat('EEEE, dd/MM/yyyy').format(selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    selectedDate = selectedDate.add(const Duration(days: 1));
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: dayClasses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No classes scheduled for this day',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dayClasses.length,
                  itemBuilder: (context, index) {
                    return _buildClassCard(dayClasses[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final sortedClasses = filteredClasses..sort((a, b) => a.startTime.compareTo(b.startTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedClasses.length,
      itemBuilder: (context, index) {
        return _buildClassCard(sortedClasses[index]);
      },
    );
  }

  Widget _buildClassCard(GymClass gymClass) {
    final timeFormat = DateFormat('HH:mm').format(gymClass.startTime) + ' - ' + DateFormat('HH:mm').format(gymClass.endTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showClassDetails(gymClass),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border(
              left: BorderSide(color: gymClass.color, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gymClass.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                gymClass.instructor,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: gymClass.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        gymClass.category,
                        style: TextStyle(
                          color: gymClass.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(timeFormat, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('${gymClass.duration} min', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.room, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(gymClass.room, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${gymClass.enrolled}/${gymClass.capacity}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: gymClass.occupancyRate > 80 ? Colors.red : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'enrolled',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: gymClass.occupancyRate / 100,
                              backgroundColor: Colors.grey[300],
                              color: gymClass.occupancyRate > 80 ? Colors.red : Colors.green,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(gymClass.level, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClassDetails(GymClass gymClass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: gymClass.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.fitness_center, color: gymClass.color, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gymClass.name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            gymClass.category,
                            style: TextStyle(
                              color: gymClass.color,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  gymClass.description,
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
                const SizedBox(height: 24),
                _buildDetailRow(Icons.person, 'Instructor', gymClass.instructor),
                _buildDetailRow(Icons.access_time, 'Time', 
                    DateFormat('HH:mm').format(gymClass.startTime) + ' - ' + DateFormat('HH:mm').format(gymClass.endTime)),
                _buildDetailRow(Icons.schedule, 'Duration', '${gymClass.duration} minutes'),
                _buildDetailRow(Icons.room, 'Room', gymClass.room),
                _buildDetailRow(Icons.trending_up, 'Level', gymClass.level),
                _buildDetailRow(Icons.people, 'Capacity', 
                    '${gymClass.enrolled}/${gymClass.capacity} (${gymClass.occupancyRate.toStringAsFixed(0)}%)'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditClassDialog(gymClass);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDelete(gymClass);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700], fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showAddClassDialog() {
    final nameController = TextEditingController();
    final instructorController = TextEditingController();
    final descController = TextEditingController();
    final capacityController = TextEditingController();
    final roomController = TextEditingController();
    
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now().add(const Duration(hours: 1));
    String selectedLevel = 'Beginner';
    String selectedCategory = 'Cardio';
    String selectedColor = '#9C27B0';

    final colorOptions = {
      'Purple': '#9C27B0',
      'Blue': '#2196F3',
      'Red': '#F44336',
      'Orange': '#FF9800',
      'Green': '#4CAF50',
      'Pink': '#E91E63',
      'Teal': '#009688',
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Class'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Class Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructorController,
                    decoration: const InputDecoration(
                      labelText: 'Instructor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capacityController,
                          decoration: const InputDecoration(
                            labelText: 'Capacity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: roomController,
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: categories.skip(1).map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          )).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedCategory = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedLevel,
                          decoration: const InputDecoration(
                            labelText: 'Level',
                            border: OutlineInputBorder(),
                          ),
                          items: ['Beginner', 'Intermediate', 'Advanced', 'All Levels']
                              .map((level) => DropdownMenuItem(
                                    value: level,
                                    child: Text(level),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedLevel = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedColor,
                    decoration: const InputDecoration(
                      labelText: 'Color',
                      border: OutlineInputBorder(),
                    ),
                    items: colorOptions.entries.map((entry) => DropdownMenuItem(
                      value: entry.value,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Color(int.parse(entry.value.replaceFirst('#', '0xFF'))),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key),
                        ],
                      ),
                    )).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedColor = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(startTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(endTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(endTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
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
                final classData = {
                  'name': nameController.text,
                  'instructor': instructorController.text,
                  'description': descController.text,
                  'start_time': startTime.toIso8601String(),
                  'end_time': endTime.toIso8601String(),
                  'capacity': int.tryParse(capacityController.text) ?? 0,
                  'enrolled': 0,
                  'level': selectedLevel,
                  'category': selectedCategory,
                  'room': roomController.text,
                  'color_hex': selectedColor,
                };

                try {
                  await supabase.from('gym_classes').insert(classData);
                  
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  
                  fetchClasses(); // Changed: removed await to prevent duplicate calls
                  
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class added successfully')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditClassDialog(GymClass gymClass) {
    final nameController = TextEditingController(text: gymClass.name);
    final instructorController = TextEditingController(text: gymClass.instructor);
    final descController = TextEditingController(text: gymClass.description);
    final capacityController = TextEditingController(text: gymClass.capacity.toString());
    final roomController = TextEditingController(text: gymClass.room);
    
    DateTime startTime = gymClass.startTime;
    DateTime endTime = gymClass.endTime;
    String selectedLevel = gymClass.level;
    String selectedCategory = gymClass.category;
    String selectedColor = gymClass.colorHex;

    final colorOptions = {
      'Purple': '#9C27B0',
      'Blue': '#2196F3',
      'Red': '#F44336',
      'Orange': '#FF9800',
      'Green': '#4CAF50',
      'Pink': '#E91E63',
      'Teal': '#009688',
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Class'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Class Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructorController,
                    decoration: const InputDecoration(
                      labelText: 'Instructor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capacityController,
                          decoration: const InputDecoration(
                            labelText: 'Capacity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: roomController,
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: categories.skip(1).map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          )).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedCategory = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedLevel,
                          decoration: const InputDecoration(
                            labelText: 'Level',
                            border: OutlineInputBorder(),
                          ),
                          items: ['Beginner', 'Intermediate', 'Advanced', 'All Levels']
                              .map((level) => DropdownMenuItem(
                                    value: level,
                                    child: Text(level),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedLevel = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedColor,
                    decoration: const InputDecoration(
                      labelText: 'Color',
                      border: OutlineInputBorder(),
                    ),
                    items: colorOptions.entries.map((entry) => DropdownMenuItem(
                      value: entry.value,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Color(int.parse(entry.value.replaceFirst('#', '0xFF'))),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key),
                        ],
                      ),
                    )).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedColor = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(startTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(endTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(endTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
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
                final classData = {
                  'name': nameController.text,
                  'instructor': instructorController.text,
                  'description': descController.text,
                  'start_time': startTime.toIso8601String(),
                  'end_time': endTime.toIso8601String(),
                  'capacity': int.tryParse(capacityController.text) ?? 0,
                  'enrolled': gymClass.enrolled,
                  'level': selectedLevel,
                  'category': selectedCategory,
                  'room': roomController.text,
                  'color_hex': selectedColor,
                };

                try {
                  await supabase
                      .from('gym_classes')
                      .update(classData)
                      .eq('id', gymClass.id);
                  
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  
                  fetchClasses(); // Changed: removed await to prevent duplicate calls
                  
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class updated successfully')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(GymClass gymClass) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Are you sure you want to delete "${gymClass.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase
                    .from('gym_classes')
                    .delete()
                    .eq('id', gymClass.id);
                
                if (!context.mounted) return;
                Navigator.pop(context);
                
                fetchClasses(); // Changed: removed await to prevent duplicate calls
                
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Class deleted successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}