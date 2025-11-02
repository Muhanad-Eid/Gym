import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrainersPage extends StatefulWidget {
  const TrainersPage({Key? key}) : super(key: key);

  @override
  State<TrainersPage> createState() => _TrainersPageState();
}

class _TrainersPageState extends State<TrainersPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> trainers = [];
  List<Map<String, dynamic>> filteredTrainers = [];
  bool isLoading = false;
  bool isAdmin = false;
  String? _selectedSpecialty;
  bool _sortAscending = true;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadTrainers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      setState(() => isAdmin = false);
    }
  }

  Future<void> _loadTrainers() async {
    try {
      setState(() => isLoading = true);
      
      var query = supabase
          .from('trainers')
          .select('id, name, specialty, avatar_url, hourly_rate, is_active, created_at');
      
      if (!_showInactive) {
        query = query.eq('is_active', true);
      }
      
      final response = await query.order('name');

      setState(() {
        trainers = List<Map<String, dynamic>>.from(response);
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load trainers: $e');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    
    filteredTrainers = trainers.where((trainer) {
      final matchesQuery = query.isEmpty ||
          trainer['name'].toString().toLowerCase().contains(query) ||
          trainer['specialty'].toString().toLowerCase().contains(query);
      
      final matchesSpecialty = _selectedSpecialty == null ||
          trainer['specialty'] == _selectedSpecialty;
      
      return matchesQuery && matchesSpecialty;
    }).toList();

    filteredTrainers.sort((a, b) {
      final comparison = a['name'].toString().compareTo(b['name'].toString());
      return _sortAscending ? comparison : -comparison;
    });
  }

  Set<String> get _specialties {
    return trainers
        .where((t) => t['specialty'] != null)
        .map((t) => t['specialty'].toString())
        .toSet();
  }

  void _showAddEditDialog({Map<String, dynamic>? trainer}) {
    final nameController = TextEditingController(text: trainer?['name'] ?? '');
    final specialtyController = TextEditingController(text: trainer?['specialty'] ?? '');
    final rateController = TextEditingController(
      text: trainer?['hourly_rate']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              trainer == null ? Icons.person_add : Icons.edit,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(trainer == null ? 'Add New Trainer' : 'Edit Trainer'),
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
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: specialtyController,
                  textCapitalization: TextCapitalization.words,
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
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                if (trainer == null) {
                  await _addTrainer(
                    nameController.text,
                    specialtyController.text,
                    double.parse(rateController.text),
                  );
                } else {
                  await _updateTrainer(
                    trainer['id'],
                    nameController.text,
                    specialtyController.text,
                    double.parse(rateController.text),
                  );
                }
              }
            },
            child: Text(trainer == null ? 'Add' : 'Update'),
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
      if (mounted) {
        _showSuccess('Trainer "$name" added successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to add trainer: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateTrainer(
    dynamic id,
    String name,
    String specialty,
    double rate,
  ) async {
    try {
      setState(() => isLoading = true);

      await supabase.from('trainers').update({
        'name': name,
        'specialty': specialty,
        'hourly_rate': rate,
      }).eq('id', id.toString());

      await _loadTrainers();
      if (mounted) {
        _showSuccess('Trainer updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to update trainer: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _toggleActiveStatus(Map<String, dynamic> trainer) async {
    final isActive = trainer['is_active'] == true;
    final newStatus = !isActive;
    
    try {
      setState(() => isLoading = true);

      await supabase.from('trainers').update({
        'is_active': newStatus,
      }).eq('id', trainer['id'].toString());

      await _loadTrainers();
      
      if (mounted) {
        _showSuccess(
          newStatus 
            ? '${trainer['name']} is now active' 
            : '${trainer['name']} is now inactive'
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to update trainer status: $e');
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
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Trainer'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${trainer['name']}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              _deleteTrainer(trainer['id'], trainer['name']);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade900,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrainer(dynamic id, String name) async {
    try {
      setState(() => isLoading = true);

      await supabase.from('trainers').delete().eq('id', id.toString());

      await _loadTrainers();
      
      if (mounted) {
        _showSuccess('Deleted $name');
      }
    } catch (e) {
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

  void _showSuccess(String message) {
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '') +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Trainers', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _showInactive = !_showInactive;
                });
                _loadTrainers();
              },
              tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrainers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() => _applyFilters()),
                        decoration: InputDecoration(
                          hintText: 'Search by trainer or specialty...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _applyFilters());
                                  },
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Filter by specialty',
                      icon: Icon(
                        Icons.filter_list,
                        color: _selectedSpecialty != null
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      onSelected: (value) {
                        setState(() {
                          _selectedSpecialty = value == 'All' ? null : value;
                          _applyFilters();
                        });
                      },
                      itemBuilder: (context) {
                        final list = ['All', ..._specialties.toList()..sort()];
                        return list
                            .map((s) => PopupMenuItem<String>(
                                  value: s,
                                  child: Row(
                                    children: [
                                      if (s == _selectedSpecialty || (s == 'All' && _selectedSpecialty == null))
                                        const Icon(Icons.check, size: 20),
                                      if (s == _selectedSpecialty || (s == 'All' && _selectedSpecialty == null))
                                        const SizedBox(width: 8),
                                      Text(s),
                                    ],
                                  ),
                                ))
                            .toList();
                      },
                    ),
                    IconButton(
                      tooltip: _sortAscending ? 'Sort A→Z' : 'Sort Z→A',
                      onPressed: () => setState(() {
                        _sortAscending = !_sortAscending;
                        _applyFilters();
                      }),
                      icon: Icon(
                        _sortAscending ? Icons.sort_by_alpha : Icons.sort,
                      ),
                    ),
                  ],
                ),
                if (_selectedSpecialty != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text('Specialty: $_selectedSpecialty'),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => setState(() {
                        _selectedSpecialty = null;
                        _applyFilters();
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.people, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '${filteredTrainers.length} trainer${filteredTrainers.length != 1 ? 's' : ''} found',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Trainers List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTrainers.isEmpty
                    ? _buildEmptyState()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;
                          if (isWide) {
                            final crossAxisCount = (constraints.maxWidth ~/ 300).clamp(2, 4);
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: filteredTrainers.length,
                              itemBuilder: (context, index) =>
                                  _buildTrainerCard(filteredTrainers[index]),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredTrainers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _buildTrainerTile(filteredTrainers[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Trainer'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No trainers found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          if (isAdmin && trainers.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add First Trainer'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrainerTile(Map<String, dynamic> trainer) {
    final isInactive = trainer['is_active'] == false;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Opacity(
        opacity: isInactive ? 0.5 : 1.0,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Hero(
            tag: 'trainer_${trainer['id']}',
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: trainer['avatar_url'] != null
                  ? CachedNetworkImageProvider(trainer['avatar_url'])
                  : null,
              child: trainer['avatar_url'] == null
                  ? Text(
                      _getInitials(trainer['name']),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  trainer['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (isInactive)
                const Chip(
                  label: Text('Inactive', style: TextStyle(fontSize: 10)),
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.fitness_center, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(trainer['specialty']),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 16, color: Colors.green),
                  Text(
                    '${trainer['hourly_rate']}/hour',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: isAdmin
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddEditDialog(trainer: trainer);
                    } else if (value == 'toggle_status') {
                      _toggleActiveStatus(trainer);
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
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            isInactive ? Icons.check_circle : Icons.cancel,
                            size: 20,
                            color: isInactive ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isInactive ? 'Mark as Active' : 'Mark as Inactive',
                            style: TextStyle(
                              color: isInactive ? Colors.green : Colors.orange,
                            ),
                          ),
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
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTrainerCard(Map<String, dynamic> trainer) {
    final isInactive = trainer['is_active'] == false;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Opacity(
        opacity: isInactive ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'trainer_${trainer['id']}',
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: trainer['avatar_url'] != null
                      ? CachedNetworkImageProvider(trainer['avatar_url'])
                      : null,
                  child: trainer['avatar_url'] == null
                      ? Text(
                          _getInitials(trainer['name']),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                trainer['name'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                trainer['specialty'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '\$${trainer['hourly_rate']}/hr',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isInactive) ...[
                const SizedBox(height: 8),
                const Chip(
                  label: Text('Inactive', style: TextStyle(fontSize: 11)),
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showAddEditDialog(trainer: trainer),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: Icon(
                        isInactive ? Icons.check_circle : Icons.cancel,
                        size: 20,
                        color: isInactive ? Colors.green : Colors.orange,
                      ),
                      onPressed: () => _toggleActiveStatus(trainer),
                      tooltip: isInactive ? 'Mark as Active' : 'Mark as Inactive',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}