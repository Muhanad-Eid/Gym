import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Subscriber {
  final String id;
  final String firstName;
  final String lastName;
  final String gender;
  final String phoneNumber;
  final String membershipType;
  final DateTime joinDate;
  final DateTime expiryDate;
  final String membershipOffer;
  final double height;
  final double weight;
  final String healthStatus;

  Subscriber({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.phoneNumber,
    required this.membershipType,
    required this.joinDate,
    required this.expiryDate,
    required this.membershipOffer,
    required this.height,
    required this.weight,
    required this.healthStatus,
  });

  String get fullName => '$firstName $lastName';

  int get daysRemaining => expiryDate.difference(DateTime.now()).inDays;

  bool get isExpiringSoon => daysRemaining <= 30 && daysRemaining > 0;
  bool get isExpired => daysRemaining < 0;

  factory Subscriber.fromMap(Map<String, dynamic> map) {
    return Subscriber(
      id: map['id'].toString(),
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      gender: map['gender'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      membershipType: map['membership_type'] ?? '',
      joinDate: DateTime.parse(map['join_date']),
      expiryDate: DateTime.parse(map['expiry_date']),
      membershipOffer: map['membership_offer'] ?? '',
      height: (map['height'] ?? 0).toDouble(),
      weight: (map['weight'] ?? 0).toDouble(),
      healthStatus: map['health_status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'phone_number': phoneNumber,
      'membership_type': membershipType,
      'join_date': joinDate.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
      'membership_offer': membershipOffer,
      'height': height,
      'weight': weight,
      'health_status': healthStatus,
    };
  }
}

class SubscribersPage extends StatefulWidget {
  const SubscribersPage({super.key});

  @override
  State<SubscribersPage> createState() => _SubscribersPageState();
}

class _SubscribersPageState extends State<SubscribersPage> {
  final _supabase = Supabase.instance.client;
  List<Subscriber> _subscribers = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String _selectedView = 'cards';

  @override
  void initState() {
    super.initState();
    _loadSubscribers();
  }

  DateTime _calculateExpiryDate(DateTime joinDate, String membershipOffer) {
    switch (membershipOffer) {
      case '1 Month':
        return DateTime(joinDate.year, joinDate.month + 1, joinDate.day);
      case '3 Months':
        return DateTime(joinDate.year, joinDate.month + 3, joinDate.day);
      case '6 Months':
        return DateTime(joinDate.year, joinDate.month + 6, joinDate.day);
      case '1 Year':
        return DateTime(joinDate.year + 1, joinDate.month, joinDate.day);
      default:
        return DateTime(joinDate.year, joinDate.month + 1, joinDate.day);
    }
  }

  Future<void> _loadSubscribers() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase.from('subscribers').select();
      setState(() {
        _subscribers = (response as List)
            .map((data) => Subscriber.fromMap(data))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addSubscriber(Subscriber s) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to add a subscriber.')),
        );
      }
      return;
    }

    try {
      await _supabase.from('subscribers').insert(s.toMap());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscriber added successfully!')),
        );
      }
      
      await _loadSubscribers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insert failed: $e')),
        );
      }
    }
  }

  Future<void> _updateSubscriber(String id, Subscriber s) async {
    try {
      await _supabase.from('subscribers').update(s.toMap()).eq('id', id);
      await _loadSubscribers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteSubscriber(String id) async {
    try {
      await _supabase.from('subscribers').delete().eq('id', id);
      await _loadSubscribers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  List<Subscriber> get _filteredSubscribers {
    if (_searchQuery.isEmpty) return _subscribers;
    final q = _searchQuery.toLowerCase();
    return _subscribers.where((s) {
      return s.firstName.toLowerCase().contains(q) ||
          s.lastName.toLowerCase().contains(q) ||
          s.phoneNumber.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.people),
            SizedBox(width: 10),
            Text('Subscribers'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_selectedView == 'cards' ? Icons.table_chart : Icons.view_agenda),
            tooltip: _selectedView == 'cards' ? 'Table View' : 'Card View',
            onPressed: () {
              setState(() {
                _selectedView = _selectedView == 'cards' ? 'table' : 'cards';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSubscribers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                _buildViewToggleButtons(),
                Expanded(
                  child: _selectedView == 'cards'
                      ? _buildCardView()
                      : _buildTableView(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Subscriber'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by name or phone...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildViewToggleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedView = 'cards';
                });
              },
              icon: const Icon(Icons.view_agenda, size: 20),
              label: const Text('Card View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedView == 'cards' 
                    ? Colors.deepPurple 
                    : Colors.grey[300],
                foregroundColor: _selectedView == 'cards' 
                    ? Colors.white 
                    : Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: _selectedView == 'cards' ? 4 : 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedView = 'table';
                });
              },
              icon: const Icon(Icons.table_chart, size: 20),
              label: const Text('Table View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedView == 'table' 
                    ? Colors.deepPurple 
                    : Colors.grey[300],
                foregroundColor: _selectedView == 'table' 
                    ? Colors.white 
                    : Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: _selectedView == 'table' ? 4 : 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView() {
    final list = _filteredSubscribers;
    if (list.isEmpty) {
      return const Center(child: Text('No subscribers found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final s = list[i];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Text(
                s.firstName.isNotEmpty ? s.firstName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              s.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${s.phoneNumber} • ${s.membershipType}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _showEditDialog(s),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(s),
                ),
              ],
            ),
            onTap: () => _showDetailsDialog(s),
          ),
        );
      },
    );
  }

  Widget _buildTableView() {
    final list = _filteredSubscribers;
    if (list.isEmpty) {
      return const Center(child: Text('No subscribers found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.deepPurple.shade100),
            columnSpacing: 24,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Gender', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Offer', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Days Left', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: list.map((s) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(s.fullName),
                    onTap: () => _showDetailsDialog(s),
                  ),
                  DataCell(Text(s.phoneNumber)),
                  DataCell(Text(s.gender)),
                  DataCell(Text(s.membershipType)),
                  DataCell(Text(s.membershipOffer)),
                  DataCell(
                    Text(
                      s.daysRemaining.toString(),
                      style: TextStyle(
                        color: s.isExpired
                            ? Colors.red
                            : (s.isExpiringSoon ? Colors.orange : Colors.green),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                          onPressed: () => _showEditDialog(s),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _confirmDelete(s),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showAddDialog() {
    final first = TextEditingController();
    final last = TextEditingController();
    final phone = TextEditingController();
    final height = TextEditingController();
    final weight = TextEditingController();

    String genderValue = 'Male';
    String membershipTypeValue = 'Basic';
    String membershipOfferValue = '1 Month';
    String healthStatusValue = 'Good';
    DateTime joinDateValue = DateTime.now();
    DateTime expiryDateValue = _calculateExpiryDate(joinDateValue, membershipOfferValue);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Subscriber'),
            content: SizedBox(
              width: 400,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: first, decoration: const InputDecoration(labelText: 'First Name')),
                    const SizedBox(height: 12),
                    TextField(controller: last, decoration: const InputDecoration(labelText: 'Last Name')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: genderValue,
                      items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setDialogState(() => genderValue = v ?? 'Male'),
                      decoration: const InputDecoration(labelText: 'Gender'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: membershipTypeValue,
                      items: ['Basic', 'Premium'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setDialogState(() => membershipTypeValue = v ?? 'Basic'),
                      decoration: const InputDecoration(labelText: 'Membership Type'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: membershipOfferValue,
                      items: ['1 Month', '3 Months', '6 Months', '1 Year'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          membershipOfferValue = v ?? '1 Month';
                          expiryDateValue = _calculateExpiryDate(joinDateValue, membershipOfferValue);
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Membership Offer'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: height,
                      decoration: const InputDecoration(labelText: 'Height (cm)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weight,
                      decoration: const InputDecoration(labelText: 'Weight (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: healthStatusValue,
                      items: ['Good', 'Not Good'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setDialogState(() => healthStatusValue = v ?? 'Good'),
                      decoration: const InputDecoration(labelText: 'Health Status'),
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
                  final newS = Subscriber(
                    id: '',
                    firstName: first.text,
                    lastName: last.text,
                    gender: genderValue,
                    phoneNumber: phone.text,
                    membershipType: membershipTypeValue,
                    joinDate: joinDateValue,
                    expiryDate: expiryDateValue,
                    membershipOffer: membershipOfferValue,
                    height: double.tryParse(height.text) ?? 0,
                    weight: double.tryParse(weight.text) ?? 0,
                    healthStatus: healthStatusValue,
                  );
                  await _addSubscriber(newS);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(Subscriber s) {
    final first = TextEditingController(text: s.firstName);
    final last = TextEditingController(text: s.lastName);
    final phone = TextEditingController(text: s.phoneNumber);
    final height = TextEditingController(text: s.height.toString());
    final weight = TextEditingController(text: s.weight.toString());

    String genderValue = s.gender;
    String membershipTypeValue = s.membershipType;
    String membershipOfferValue = s.membershipOffer;
    String healthStatusValue = s.healthStatus;
    DateTime joinDateValue = s.joinDate;
    DateTime expiryDateValue = s.expiryDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Subscriber'),
            content: SizedBox(
              width: 400,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: first, decoration: const InputDecoration(labelText: 'First Name')),
                    const SizedBox(height: 12),
                    TextField(controller: last, decoration: const InputDecoration(labelText: 'Last Name')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: genderValue,
                      items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setDialogState(() => genderValue = v ?? 'Male'),
                      decoration: const InputDecoration(labelText: 'Gender'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: membershipTypeValue,
                      items: ['Basic', 'Premium'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setDialogState(() => membershipTypeValue = v ?? 'Basic'),
                      decoration: const InputDecoration(labelText: 'Membership Type'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: membershipOfferValue,
                      items: ['1 Month', '3 Months', '6 Months', '1 Year'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          membershipOfferValue = v ?? '1 Month';
                          expiryDateValue = _calculateExpiryDate(joinDateValue, membershipOfferValue);
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Membership Offer'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: height,
                      decoration: const InputDecoration(labelText: 'Height (cm)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weight,
                      decoration: const InputDecoration(labelText: 'Weight (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: healthStatusValue,
                      items: ['Good', 'Not Good'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setDialogState(() => healthStatusValue = v ?? 'Good'),
                      decoration: const InputDecoration(labelText: 'Health Status'),
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
                  final updated = Subscriber(
                    id: s.id,
                    firstName: first.text,
                    lastName: last.text,
                    gender: genderValue,
                    phoneNumber: phone.text,
                    membershipType: membershipTypeValue,
                    joinDate: joinDateValue,
                    expiryDate: expiryDateValue,
                    membershipOffer: membershipOfferValue,
                    height: double.tryParse(height.text) ?? 0,
                    weight: double.tryParse(weight.text) ?? 0,
                    healthStatus: healthStatusValue,
                  );
                  await _updateSubscriber(s.id, updated);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(Subscriber s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscriber'),
        content: Text('Are you sure you want to delete ${s.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteSubscriber(s.id);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(Subscriber s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.fullName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(Icons.phone, 'Phone', s.phoneNumber),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.person, 'Gender', s.gender),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.card_membership, 'Membership', s.membershipType),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.local_offer, 'Offer', s.membershipOffer),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.timer, 'Days Left', s.daysRemaining.toString(),
                color: s.isExpired ? Colors.red : (s.isExpiringSoon ? Colors.orange : Colors.green)),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.height, 'Height', '${s.height} cm'),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.monitor_weight, 'Weight', '${s.weight} kg'),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.favorite, 'Health', s.healthStatus,
                color: s.healthStatus == 'Good' ? Colors.green : Colors.red),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showEditDialog(s);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}