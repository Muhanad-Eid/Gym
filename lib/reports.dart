import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final supabase = Supabase.instance.client;
  
  bool isLoading = true;
  String selectedPeriod = 'This Month';
  
  // Analytics Data
  int totalMembers = 0;
  int totalReservations = 0;
  int activeTrainers = 0;
  double totalRevenue = 0.0;
  int thisMonthReservations = 0;
  int lastMonthReservations = 0;
  
  Map<String, int> monthlyReservations = {};
  Map<String, double> trainerPopularity = {};
  Map<String, int> specialtyDistribution = {};
  Map<String, double> dailyRevenue = {};
  List<Map<String, dynamic>> topTrainers = [];
  Map<String, int> reservationsByStatus = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => isLoading = true);
    
    try {
      await Future.wait([
        _loadTotalMembers(),
        _loadTotalReservations(),
        _loadActiveTrainers(),
        _loadTotalRevenue(),
        _loadMonthlyReservations(),
        _loadTrainerPopularity(),
        _loadSpecialtyDistribution(),
        _loadDailyRevenue(),
        _loadTopTrainers(),
        _loadReservationsByStatus(),
      ]);
      
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load reports: $e');
    }
  }

  Future<void> _loadTotalMembers() async {
    try {
      // Count unique users who made reservations
      final response = await supabase
          .from('reservations')
          .select('user_id')
          .eq('status', 'confirmed');
      
      final uniqueUsers = <String>{};
      for (var reservation in response) {
        uniqueUsers.add(reservation['user_id'].toString());
      }
      
      totalMembers = uniqueUsers.length;
    } catch (e) {
      print('Error loading members: $e');
    }
  }

  Future<void> _loadTotalReservations() async {
    try {
      final response = await supabase
          .from('reservations')
          .select('id, created_at')
          .eq('status', 'confirmed');
      
      totalReservations = response.length;
      
      // Calculate this month vs last month
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      
      thisMonthReservations = response.where((r) {
        final date = DateTime.parse(r['created_at']);
        return date.isAfter(thisMonthStart);
      }).length;
      
      lastMonthReservations = response.where((r) {
        final date = DateTime.parse(r['created_at']);
        return date.isAfter(lastMonthStart) && date.isBefore(thisMonthStart);
      }).length;
    } catch (e) {
      print('Error loading reservations: $e');
    }
  }

  Future<void> _loadActiveTrainers() async {
    try {
      final response = await supabase
          .from('trainers')
          .select('id')
          .eq('is_active', true);
      
      activeTrainers = response.length;
    } catch (e) {
      print('Error loading trainers: $e');
    }
  }

  Future<void> _loadTotalRevenue() async {
    try {
      final response = await supabase
          .from('reservations')
          .select('total_price')
          .eq('status', 'confirmed');
      
      totalRevenue = response.fold<double>(
        0.0,
        (sum, reservation) => sum + (reservation['total_price'] as num).toDouble(),
      );
    } catch (e) {
      print('Error loading revenue: $e');
    }
  }

  Future<void> _loadMonthlyReservations() async {
    try {
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
      
      final response = await supabase
          .from('reservations')
          .select('created_at')
          .eq('status', 'confirmed')
          .gte('created_at', sixMonthsAgo.toIso8601String());
      
      final Map<String, int> monthly = {};
      
      for (var reservation in response) {
        final date = DateTime.parse(reservation['created_at']);
        final monthKey = DateFormat('MMM').format(date);
        monthly[monthKey] = (monthly[monthKey] ?? 0) + 1;
      }
      
      // Fill in missing months
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final key = DateFormat('MMM').format(month);
        monthly.putIfAbsent(key, () => 0);
      }
      
      monthlyReservations = Map.fromEntries(
        monthly.entries.toList()..sort((a, b) {
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return months.indexOf(a.key).compareTo(months.indexOf(b.key));
        }),
      );
    } catch (e) {
      print('Error loading monthly reservations: $e');
    }
  }

  Future<void> _loadTrainerPopularity() async {
    try {
      final response = await supabase
          .from('reservations')
          .select('trainer_id, trainers(name)')
          .eq('status', 'confirmed');
      
      final Map<String, int> popularity = {};
      
      for (var reservation in response) {
        final trainerName = reservation['trainers']['name'].toString();
        popularity[trainerName] = (popularity[trainerName] ?? 0) + 1;
      }
      
      // Convert to percentages
      final total = popularity.values.fold<int>(0, (sum, count) => sum + count);
      if (total > 0) {
        trainerPopularity = popularity.map(
          (name, count) => MapEntry(name, (count / total * 100)),
        );
      }
    } catch (e) {
      print('Error loading trainer popularity: $e');
    }
  }

  Future<void> _loadSpecialtyDistribution() async {
    try {
      final response = await supabase
          .from('reservations')
          .select('trainer_id, trainers(specialty)')
          .eq('status', 'confirmed');
      
      final Map<String, int> distribution = {};
      
      for (var reservation in response) {
        final specialty = reservation['trainers']['specialty'].toString();
        distribution[specialty] = (distribution[specialty] ?? 0) + 1;
      }
      
      specialtyDistribution = distribution;
    } catch (e) {
      print('Error loading specialty distribution: $e');
    }
  }

  Future<void> _loadDailyRevenue() async {
    try {
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 6));
      
      final response = await supabase
          .from('reservations')
          .select('date, total_price')
          .eq('status', 'confirmed')
          .gte('date', last7Days.toIso8601String());
      
      final Map<String, double> daily = {};
      
      for (var reservation in response) {
        final date = DateTime.parse(reservation['date']);
        final dayKey = DateFormat('EEE').format(date);
        daily[dayKey] = (daily[dayKey] ?? 0.0) + (reservation['total_price'] as num).toDouble();
      }
      
      // Fill in missing days
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final key = DateFormat('EEE').format(day);
        daily.putIfAbsent(key, () => 0.0);
      }
      
      dailyRevenue = daily;
    } catch (e) {
      print('Error loading daily revenue: $e');
    }
  }

  Future<void> _loadTopTrainers() async {
    try {
      final response = await supabase
          .from('reservations')
          .select('trainer_id, total_price, trainers(name, specialty, avatar_url)')
          .eq('status', 'confirmed');
      
      final Map<String, Map<String, dynamic>> trainerStats = {};
      
      for (var reservation in response) {
        final trainerId = reservation['trainer_id'].toString();
        final trainerData = reservation['trainers'];
        
        if (!trainerStats.containsKey(trainerId)) {
          trainerStats[trainerId] = {
            'name': trainerData['name'],
            'specialty': trainerData['specialty'],
            'avatar_url': trainerData['avatar_url'],
            'bookings': 0,
            'revenue': 0.0,
          };
        }
        
        trainerStats[trainerId]!['bookings'] += 1;
        trainerStats[trainerId]!['revenue'] += (reservation['total_price'] as num).toDouble();
      }
      
      topTrainers = trainerStats.values.toList()
        ..sort((a, b) => (b['bookings'] as int).compareTo(a['bookings'] as int));
      
      topTrainers = topTrainers.take(5).toList();
    } catch (e) {
      print('Error loading top trainers: $e');
    }
  }

  Future<void> _loadReservationsByStatus() async {
    try {
      final response = await supabase
          .from('reservations')
          .select('status');
      
      final Map<String, int> statusCount = {};
      
      for (var reservation in response) {
        final status = reservation['status'].toString();
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }
      
      reservationsByStatus = statusCount;
    } catch (e) {
      print('Error loading reservations by status: $e');
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSectionTitle('Overview'),
                    const SizedBox(height: 12),
                    _buildOverviewCards(),
                    const SizedBox(height: 24),

                    // Growth Indicator
                    _buildGrowthIndicator(),
                    const SizedBox(height: 24),

                    // Monthly Reservations Chart
                    _buildSectionTitle('Reservations Trend'),
                    const SizedBox(height: 12),
                    _buildMonthlyReservationsChart(),
                    const SizedBox(height: 24),

                    // Daily Revenue Chart
                    _buildSectionTitle('Weekly Revenue'),
                    const SizedBox(height: 12),
                    _buildDailyRevenueChart(),
                    const SizedBox(height: 24),

                    // Trainer Popularity
                    _buildSectionTitle('Trainer Performance'),
                    const SizedBox(height: 12),
                    _buildTrainerPopularityChart(),
                    const SizedBox(height: 24),

                    // Top Trainers List
                    _buildSectionTitle('Top 5 Trainers'),
                    const SizedBox(height: 12),
                    _buildTopTrainersList(),
                    const SizedBox(height: 24),

                    // Specialty Distribution
                    _buildSectionTitle('Popular Specialties'),
                    const SizedBox(height: 12),
                    _buildSpecialtyBars(),
                    const SizedBox(height: 24),

                    // Reservation Status
                    _buildSectionTitle('Reservation Status'),
                    const SizedBox(height: 12),
                    _buildStatusDistribution(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'Total Members',
          totalMembers.toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Reservations',
          totalReservations.toString(),
          Icons.calendar_today,
          Colors.green,
        ),
        _buildStatCard(
          'Active Trainers',
          activeTrainers.toString(),
          Icons.fitness_center,
          Colors.orange,
        ),
        _buildStatCard(
          'Total Revenue',
          '\$${totalRevenue.toStringAsFixed(0)}',
          Icons.attach_money,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthIndicator() {
    final growth = lastMonthReservations > 0
        ? ((thisMonthReservations - lastMonthReservations) / lastMonthReservations * 100)
        : 0.0;
    
    final isPositive = growth >= 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              size: 40,
              color: isPositive ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${growth.abs().toStringAsFixed(1)}% ${isPositive ? 'Growth' : 'Decline'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compared to last month ($lastMonthReservations → $thisMonthReservations)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyReservationsChart() {
    if (monthlyReservations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    final List<BarChartGroupData> barGroups = [];
    int index = 0;
    
    monthlyReservations.forEach((month, value) {
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              color: Colors.deepPurple,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            )
          ],
        ),
      );
      index++;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 12),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final monthList = monthlyReservations.keys.toList();
                      if (value.toInt() >= 0 && value.toInt() < monthList.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthList[value.toInt()],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.shade300,
                    strokeWidth: 1,
                  );
                },
              ),
              barGroups: barGroups,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRevenueChart() {
    if (dailyRevenue.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    final spots = <FlSpot>[];
    int index = 0;
    
    dailyRevenue.forEach((day, revenue) {
      spots.add(FlSpot(index.toDouble(), revenue));
      index++;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final days = dailyRevenue.keys.toList();
                      if (value.toInt() >= 0 && value.toInt() < days.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            days[value.toInt()],
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
                },
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerPopularityChart() {
    if (trainerPopularity.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    final sections = trainerPopularity.entries.map((entry) {
      final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.pink];
      final colorIndex = trainerPopularity.keys.toList().indexOf(entry.key) % colors.length;
      
      return PieChartSectionData(
        title: '${entry.key}\n${entry.value.toStringAsFixed(1)}%',
        value: entry.value,
        radius: 100,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        color: colors[colorIndex],
      );
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 280,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50,
              sectionsSpace: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopTrainersList() {
    if (topTrainers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topTrainers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final trainer = topTrainers[index];
          final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '${index + 1}';
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.withOpacity(0.1),
              child: Text(
                medal,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            title: Text(
              trainer['name'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(trainer['specialty']),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${trainer['bookings']} bookings',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '\$${trainer['revenue'].toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecialtyBars() {
    if (specialtyDistribution.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    final maxValue = specialtyDistribution.values.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: specialtyDistribution.entries.map((entry) {
            final percentage = (entry.value / maxValue);
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${entry.value} bookings',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusDistribution() {
    if (reservationsByStatus.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: reservationsByStatus.entries.map((entry) {
            final color = entry.key == 'confirmed'
                ? Colors.green
                : entry.key == 'cancelled'
                    ? Colors.red
                    : Colors.orange;
            
            return Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: color.withOpacity(0.2),
                  child: Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.key.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}