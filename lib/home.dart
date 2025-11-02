import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

void main() {
  runApp(const GymManagementApp());
}

class GymManagementApp extends StatelessWidget {
  const GymManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Roboto',
      ),
      home: const GymHomePage(),
    );
  }
}

class GymHomePage extends StatefulWidget {
  const GymHomePage({super.key});

  @override
  State<GymHomePage> createState() => _GymHomePageState();
}

class _GymHomePageState extends State<GymHomePage> {
  late Future<Map<String, dynamic>> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _fetchHomeData();
  }

  Future<Map<String, dynamic>> _fetchHomeData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      final membersResponse = await Supabase.instance.client
          .from('subscribers')
          .select('id');

      final trainersResponse = await Supabase.instance.client
          .from('trainers')
          .select('id');

      return {
        'totalMembers': membersResponse.length,
        'totalTrainers': trainersResponse.length,
        'userName': user?.email?.split('@').first ?? 'Admin',
      };
    } catch (error) {
      return {
        'totalMembers': 0,
        'totalTrainers': 0,
        'userName': 'Admin',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isSmallScreen),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  child: Column(
                    children: [
                      FutureBuilder<Map<String, dynamic>>(
                        future: _homeDataFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildWelcomeCardSkeleton(isSmallScreen);
                          }
                          
                          final data = snapshot.data ?? {};
                          return _buildWelcomeCard(isSmallScreen, data);
                        },
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      _buildMenuGrid(context, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 20 : 24),
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

  Widget _buildHeader(bool isSmallScreen) {
    return Builder(
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 20,
          vertical: isSmallScreen ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: isSmallScreen ? 24 : 28,
              ),
            ),
            SizedBox(width: isSmallScreen ? 10 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gym Manager',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: const Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: const Color(0xFF2C3E50),
                size: isSmallScreen ? 20 : 24,
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            InkWell(
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Log Out'),
                      ],
                    ),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/sign_in');
                  }
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.logout,
                  color: const Color(0xFF2C3E50),
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCardSkeleton(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 180,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: isSmallScreen ? 50 : 60,
                height: isSmallScreen ? 50 : 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(bool isSmallScreen, Map<String, dynamic> data) {
    return AnimatedWelcomeCard(
      isSmallScreen: isSmallScreen,
      data: data,
    );
  }

  Widget _buildMenuGrid(BuildContext context, bool isSmallScreen) {
    final menuItems = [
      MenuItemData(
        title: 'Subscribers',
        subtitle: 'Manage members',
        icon: Icons.people_outline,
        color: Colors.blue,
        onTap: () => Navigator.pushNamed(context, '/subscribers'),
      ),
      MenuItemData(
        title: 'Subscriptions',
        subtitle: 'Bundles & plans',
        icon: Icons.card_membership_outlined,
        color: Colors.purple,
        onTap: () => Navigator.pushNamed(context, '/subscriptions'),
      ),
      MenuItemData(
        title: 'Schedule',
        subtitle: 'Classes & timing',
        icon: Icons.calendar_today_outlined,
        color: Colors.orange,
        onTap: () => Navigator.pushNamed(context, '/schedule'),
      ),
      MenuItemData(
        title: 'Reservations',
        subtitle: 'Book classes',
        icon: Icons.event_available_outlined,
        color: Colors.teal,
        onTap: () => Navigator.pushNamed(context, '/reservation'),
      ),
      MenuItemData(
        title: 'Reports',
        subtitle: 'Monthly insights',
        icon: Icons.assessment_outlined,
        color: Colors.indigo,
        onTap: () => Navigator.pushNamed(context, '/reports'),
      ),
      MenuItemData(
        title: 'Trainers',
        subtitle: 'Staff management',
        icon: Icons.sports_martial_arts_outlined,
        color: Colors.red,
        onTap: () => Navigator.pushNamed(context, '/trainers'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: isSmallScreen ? 12 : 16,
        mainAxisSpacing: isSmallScreen ? 12 : 16,
        childAspectRatio: isSmallScreen ? 0.95 : 1.0,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        return _buildMenuItem(menuItems[index], isSmallScreen);
      },
    );
  }

  Widget _buildMenuItem(MenuItemData item, bool isSmallScreen) {
    return Builder(
      builder: (context) {
        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    item.icon,
                    size: isSmallScreen ? 30 : 36,
                    color: item.color,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 10 : 12),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmallScreen ? 3 : 4),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnimatedWelcomeCard extends StatefulWidget {
  final bool isSmallScreen;
  final Map<String, dynamic> data;

  const AnimatedWelcomeCard({
    Key? key,
    required this.isSmallScreen,
    required this.data,
  }) : super(key: key);

  @override
  State<AnimatedWelcomeCard> createState() => _AnimatedWelcomeCardState();
}

class _AnimatedWelcomeCardState extends State<AnimatedWelcomeCard>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _iconColumn1Controller;
  late AnimationController _iconColumn2Controller;
  late AnimationController _iconColumn3Controller;
  late Animation<Offset> _col1Animation;
  late Animation<Offset> _col2Animation;
  late Animation<Offset> _col3Animation;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat(reverse: true);

    _iconColumn1Controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _iconColumn2Controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _iconColumn3Controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _col1Animation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -8),
    ).animate(CurvedAnimation(parent: _iconColumn1Controller, curve: Curves.easeInOut));

    _col2Animation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -8),
    ).animate(CurvedAnimation(parent: _iconColumn2Controller, curve: Curves.easeInOut));

    _col3Animation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -8),
    ).animate(CurvedAnimation(parent: _iconColumn3Controller, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _iconColumn2Controller.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _iconColumn3Controller.forward();
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _iconColumn1Controller.dispose();
    _iconColumn2Controller.dispose();
    _iconColumn3Controller.dispose();
    super.dispose();
  }

  Color _getColor(double progress) {
    // Rich vibrant color transitions
    if (progress < 0.2) {
      // Deep Purple to Blue
      return Color.lerp(
        Colors.deepPurple.shade500,
        Colors.blue.shade500,
        progress / 0.2,
      )!;
    } else if (progress < 0.4) {
      // Blue to Indigo
      return Color.lerp(
        Colors.blue.shade500,
        Colors.indigo.shade500,
        (progress - 0.2) / 0.2,
      )!;
    } else if (progress < 0.6) {
      // Indigo to Purple
      return Color.lerp(
        Colors.indigo.shade500,
        Colors.purple.shade500,
        (progress - 0.4) / 0.2,
      )!;
    } else if (progress < 0.8) {
      // Purple to Violet/Pink
      return Color.lerp(
        Colors.purple.shade500,
        Colors.pink.shade500,
        (progress - 0.6) / 0.2,
      )!;
    } else {
      // Pink back to Deep Purple
      return Color.lerp(
        Colors.pink.shade500,
        Colors.deepPurple.shade500,
        (progress - 0.8) / 0.2,
      )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        final progress = _backgroundController.value;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(widget.isSmallScreen ? 20 : 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                -0.8 + (sin(progress * 3.14) * 0.8),
                -0.8 + (cos(progress * 3.14) * 0.8),
              ),
              end: Alignment(
                0.8 - (sin(progress * 3.14) * 0.8),
                0.8 - (cos(progress * 3.14) * 0.8),
              ),
              colors: [
                _getColor(progress),
                _getColor((progress + 0.33) % 1.0),
                _getColor((progress + 0.66) % 1.0),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
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
                          'Welcome Back, ${widget.data['userName']}!',
                          style: TextStyle(
                            fontSize: widget.isSmallScreen ? 22 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: widget.isSmallScreen ? 6 : 8),
                        Text(
                          'Manage gym efficiently',
                          style: TextStyle(
                            fontSize: widget.isSmallScreen ? 13 : 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(widget.isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _iconColumn1Controller,
                        _iconColumn2Controller,
                        _iconColumn3Controller,
                      ]),
                      builder: (context, child) {
                        return CustomPaint(
                          painter: BarChartPainter(
                            col1Offset: _col1Animation.value.dy,
                            col2Offset: _col2Animation.value.dy,
                            col3Offset: _col3Animation.value.dy,
                            size: widget.isSmallScreen ? 28.0 : 32.0,
                          ),
                          size: Size(
                            widget.isSmallScreen ? 28 : 32,
                            widget.isSmallScreen ? 28 : 32,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: widget.isSmallScreen ? 16 : 20),
              Container(
                padding: EdgeInsets.all(widget.isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      'Total Members',
                      widget.data['totalMembers'].toString(),
                      Icons.people,
                      widget.isSmallScreen,
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      'Total Trainers',
                      (widget.data['totalTrainers'] ?? 0).toString(),
                      Icons.sports_martial_arts,
                      widget.isSmallScreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    bool isSmallScreen,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 11,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 2,
      height: 60,
      color: Colors.white.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class MenuItemData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  MenuItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class BarChartPainter extends CustomPainter {
  final double col1Offset;
  final double col2Offset;
  final double col3Offset;
  final double size;

  BarChartPainter({
    required this.col1Offset,
    required this.col2Offset,
    required this.col3Offset,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final width = canvasSize.width;
    final height = canvasSize.height;
    final spacing = width / 7;

    // Column 1
    final col1X = spacing;
    final col1Height = height * 0.4;
    canvas.drawLine(
      Offset(col1X, height - col1Height + col1Offset),
      Offset(col1X, height + col1Offset),
      paint,
    );

    // Column 2
    final col2X = spacing * 3;
    final col2Height = height * 0.7;
    canvas.drawLine(
      Offset(col2X, height - col2Height + col2Offset),
      Offset(col2X, height + col2Offset),
      paint,
    );

    // Column 3
    final col3X = spacing * 5;
    final col3Height = height * 0.5;
    canvas.drawLine(
      Offset(col3X, height - col3Height + col3Offset),
      Offset(col3X, height + col3Offset),
      paint,
    );
  }

  @override
  bool shouldRepaint(BarChartPainter oldDelegate) {
    return oldDelegate.col1Offset != col1Offset ||
        oldDelegate.col2Offset != col2Offset ||
        oldDelegate.col3Offset != col3Offset;
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
            ),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This page is under development',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}