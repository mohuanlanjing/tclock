import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'services/pomodoro_service.dart';
import 'services/records_service.dart';
import 'pages/manage_topics_page.dart';
import 'pages/records_page.dart';

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
        ChangeNotifierProvider(create: (_) => RecordsService()..init()),
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
  final TextEditingController _topicController = TextEditingController(text: '日常');
  final TextEditingController _subTaskController = TextEditingController();

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
      // 写入结束时间
      await context.read<RecordsService>().finishOngoing();
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
    _topicController.dispose();
    _subTaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<PomodoroService>();
    final recordsService = context.watch<RecordsService>();

    // 默认主题：优先最近一次使用
    if ((_topicController.text.isEmpty || _topicController.text == '日常') &&
        (recordsService.lastTopicName != null && recordsService.lastTopicName!.isNotEmpty)) {
      _topicController.text = recordsService.lastTopicName!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TClock 番茄'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '管理主题',
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageTopicsPage()),
            ),
          ),
          IconButton(
            tooltip: '查看记录',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecordsPage()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 主题与子任务输入
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '本次要做什么？',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: recordsService.topics.any((t) => t.name == _topicController.text)
                        ? _topicController.text
                        : null,
                    items: [
                      ...recordsService.topics.map((t) => DropdownMenuItem(
                            value: t.name,
                            child: Text(t.name),
                          )),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      _topicController.text = v;
                    },
                    decoration: const InputDecoration(labelText: '选择主题'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: '或输入新主题',
                      hintText: '例如：学习/开发',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _subTaskController,
                    decoration: const InputDecoration(
                      labelText: '子任务（可留空）',
                      hintText: '例如：实现登录接口',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            // 快捷设置按钮
            Text(
              '快捷设置',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: service.isRunning ? null : () => service.setPresetDuration(const Duration(minutes: 30)),
                  child: const Text('30分钟'),
                ),
                OutlinedButton(
                  onPressed: service.isRunning ? null : () => service.setPresetDuration(const Duration(minutes: 35)),
                  child: const Text('35分钟'),
                ),
                OutlinedButton(
                  onPressed: service.isRunning ? null : () => service.setPresetDuration(const Duration(minutes: 40)),
                  child: const Text('40分钟'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: service.isRunning
                      ? null
                      : () async {
                          final records = context.read<RecordsService>();
                          final String topic = _topicController.text.trim().isEmpty ? '日常' : _topicController.text.trim();
                          final String? subTask = _subTaskController.text.trim().isEmpty ? null : _subTaskController.text.trim();
                          await records.startSession(
                            topicName: topic,
                            subTask: subTask,
                            durationMinutes: service.lastSetDuration.inMinutes,
                          );
                          service.start();
                        },
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
                  onPressed: () async {
                    // 取消未完成记录
                    await context.read<RecordsService>().cancelOngoing();
                    service.reset();
                  },
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
