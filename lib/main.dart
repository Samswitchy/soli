import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Soli',
      theme: ThemeData(useMaterial3: true),
      home: const MiningHomePage(),
    );
  }
}

class MiningHomePage extends StatefulWidget {
  const MiningHomePage({super.key});

  @override
  State<MiningHomePage> createState() => _MiningHomePageState();
}

class _MiningHomePageState extends State<MiningHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeTab(),
    TasksTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: "Tasks"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  double _balance = 0.0;
  double _checking = 1.33;
  double _miningReward = 3.33;
  Duration _duration = const Duration(hours: 24);
  Timer? _timer;
  DateTime? _miningStartTime;
  bool _isMining = false;
  double _miningIncrement = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMiningState();
  }

  Future<void> _loadMiningState() async {
    final prefs = await SharedPreferences.getInstance();

    double savedBalance = prefs.getDouble('mining_balance') ?? 0.0;
    bool wasMining = prefs.getBool('is_mining') ?? false;
    int savedSeconds = prefs.getInt('remaining_duration') ?? 0;
    int? startTimeMillis = prefs.getInt('mining_start_time');
    bool completed = prefs.getBool('mining_completed') ?? false;

    Duration remaining = Duration(seconds: savedSeconds);
    DateTime? savedStartTime = startTimeMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startTimeMillis)
        : null;

    if (wasMining && savedStartTime != null) {
      final now = DateTime.now();
      final elapsed = now.difference(savedStartTime);

      int elapsedSeconds = elapsed.inSeconds > remaining.inSeconds
          ? remaining.inSeconds
          : elapsed.inSeconds;

      double incrementPerSecond = _miningReward / (24 * 60 * 60);
      savedBalance += incrementPerSecond * elapsedSeconds;

      remaining -= Duration(seconds: elapsedSeconds);
      wasMining = remaining.inSeconds > 0;
    }

    setState(() {
      _balance = savedBalance;
      _isMining = wasMining;
      _duration = remaining;
      _miningStartTime = DateTime.now();
    });

    if (_isMining && _duration.inSeconds > 0) {
      _resumeMining();
    }

    if (completed) {
      Future.delayed(Duration.zero, () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: const [
                Icon(Icons.notifications_active, color: Colors.white),
                SizedBox(width: 10),
                Text('Mining completed!', style: TextStyle(color: Colors.white)),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });

      await prefs.setBool('mining_completed', false);
    }
  }

  Future<void> _saveMiningState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('mining_balance', _balance);
    await prefs.setBool('is_mining', _isMining);
    await prefs.setInt('remaining_duration', _duration.inSeconds);

    if (_miningStartTime != null) {
      await prefs.setInt('mining_start_time', _miningStartTime!.millisecondsSinceEpoch);
    }

    await prefs.setBool('mining_completed', !_isMining && _duration.inSeconds == 0);
  }

  void _startMining() async {
    if (_isMining) return;

    setState(() {
      _isMining = true;
      _balance += _checking;
      _duration = const Duration(hours: 24);
      _miningStartTime = DateTime.now();
    });

    await _saveMiningState();
    _resumeMining();
  }

  void _resumeMining() {
    _miningStartTime = DateTime.now();
    _timer?.cancel();

    int totalSeconds = 24 * 60 * 60;
    _miningIncrement = _miningReward / totalSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_duration.inSeconds > 0) {
          _duration -= const Duration(seconds: 1);
          _balance += _miningIncrement;

          if (_duration.inSeconds % 60 == 0) {
            _saveMiningState();
          }
        } else {
          _isMining = false;
          _balance = double.parse(_balance.toStringAsFixed(2));
          timer.cancel();
          _saveMiningState();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Row(
                children: const [
                  Icon(Icons.notifications_active, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Mining completed!', style: TextStyle(color: Colors.white)),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Soli', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final completed = prefs.getBool('mining_completed') ?? false;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(completed ? 'Mining completed!' : 'No new notifications'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7B2FF7), Color(0xFF4C8EFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Start Mining',
              style: TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your Balance: ${_balance.toStringAsFixed(5)} tokens',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 40),
            Text(
              _formatDuration(_duration),
              style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: _isMining ? null : _startMining,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                backgroundColor: const Color(0xFFFFC107),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text(
                'Start Mining',
                style: TextStyle(fontSize: 20, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text('Tasks Page', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text('Settings Page', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
