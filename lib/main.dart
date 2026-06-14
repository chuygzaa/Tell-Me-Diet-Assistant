import 'package:flutter/material.dart';
import 'screens/meal_logger_screen.dart';
import 'screens/history_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/weight_screen.dart';
import 'screens/settings_screen.dart';
import 'services/profile_service.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DietApplication());
}

class DietApplication extends StatelessWidget {
  const DietApplication({super.key});



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operations Nutrition Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.tealAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardTheme(color: Color(0xFF1E1E1E)),
      ),
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    ProfileService.isOnboardingComplete()
        .then((v) => setState(() => _onboarded = v));
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
            child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }
    if (_onboarded == false) {
      return OnboardingScreen(onDone: () => setState(() => _onboarded = true));
    }
    return const MainNavigator();
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.mic, label: 'Meal Logger'),
    _NavItem(icon: Icons.history, label: 'History'),
    _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.monitor_weight_outlined, label: 'Weight'),
    _NavItem(icon: Icons.settings, label: 'Settings'),
  ];

  List<Widget> get _screens => [
    const MealLoggerScreen(),
    HistoryScreen(isActive: _currentIndex == 1),
    AnalyticsScreen(isActive: _currentIndex == 2),
    const WeightScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          _navItems[_currentIndex].label.toUpperCase(),
          style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1E1E1E)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.bolt, color: Colors.tealAccent, size: 36),
                  SizedBox(height: 8),
                  Text('DIET LOG // DISCIPLINE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('Operations Nutrition Engine',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            ...List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final isActive = _currentIndex == i;
              return ListTile(
                leading: Icon(item.icon,
                    color: isActive ? Colors.tealAccent : Colors.grey),
                title: Text(item.label,
                    style: TextStyle(
                        color: isActive ? Colors.tealAccent : Colors.white,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal)),
                selected: isActive,
                selectedTileColor: Colors.tealAccent.withOpacity(0.1),
                onTap: () {
                  setState(() => _currentIndex = i);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}