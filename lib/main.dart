import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'services/pomodoro_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PomodoroService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TClock',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  StreamSubscription<void>? _sub;

  String _formatDuration(Duration d) {
    final String mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final int hours = d.inHours;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$mm:$ss'
        : '$mm:$ss';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    final service = context.read<PomodoroService>();
    _sub = service.onFinished.listen((_) async {
      if (!mounted) return;
      // Foreground dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('番茄结束'),
          content: const Text('恭喜完成一个番茄！休息一下吧。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('好的'),
            )
          ],
        ),
      );
      // System notification (sound)
      await NotificationService.instance.showFinishNotification();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<PomodoroService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TClock 番茄'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatDuration(service.remaining),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: service.isRunning ? null : service.decreaseByFiveMinutes,
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 32,
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: service.isRunning ? null : service.increaseByFiveMinutes,
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 32,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: service.isRunning ? null : service.start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始'),
                ),
                ElevatedButton.icon(
                  onPressed: service.isRunning && !service.isPaused ? service.pause : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('暂停'),
                ),
                ElevatedButton.icon(
                  onPressed: service.isRunning && service.isPaused ? service.resume : null,
                  icon: const Icon(Icons.play_circle),
                  label: const Text('继续'),
                ),
                OutlinedButton.icon(
                  onPressed: service.reset,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('重置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
