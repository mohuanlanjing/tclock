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
  final TextEditingController _newTopicController = TextEditingController();
  final TextEditingController _subTaskController = TextEditingController();

  // 主题选择模式：false=选择已有主题，true=使用新主题
  bool _useNewTopic = false;
  String? _selectedTopicName; // 选择已有主题时的值
  bool _initTopicApplied = false; // 仅在首次进入时应用最近主题

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

    // 首次进入时，根据最近主题进行一次默认设置，不在 build 中覆盖用户输入
    final recordsService = context.read<RecordsService>();
    _applyDefaultTopic(recordsService);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _newTopicController.dispose();
    _subTaskController.dispose();
    super.dispose();
  }

  void _applyDefaultTopic(RecordsService recordsService) {
    if (_initTopicApplied) return;
    _initTopicApplied = true;
    final String? last = recordsService.lastTopicName;
    if (last == null || last.isEmpty) {
      // 保持默认：选择已有主题模式且不选中任何，提示用户选择
      _useNewTopic = false;
      _selectedTopicName = null;
      return;
    }
    final bool exists = recordsService.topics.any((t) => t.name == last);
    if (exists) {
      _useNewTopic = false;
      _selectedTopicName = last;
    } else {
      _useNewTopic = true;
      _newTopicController.text = last;
    }
  }

  Future<void> _handleStartPressed(PomodoroService service, BuildContext context) async {
    final records = context.read<RecordsService>();
    final String topic = _useNewTopic
        ? _newTopicController.text.trim()
        : (_selectedTopicName ?? '').trim();
    final String? subTask = _subTaskController.text.trim().isEmpty ? null : _subTaskController.text.trim();

    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择主题或输入新主题')),
      );
      return;
    }

    // 若存在未完成记录，先提示用户去记录页处理，避免产生多条同时进行的记录
    if (records.ongoing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已有未完成记录，请在记录页处理后再开始新的番茄')),
      );
      return;
    }

    await records.startSession(
      topicName: topic,
      subTask: subTask,
      durationMinutes: service.lastSetDuration.inMinutes,
    );
    service.start();
  }

  Widget _buildTopicSection(ThemeData theme, RecordsService recordsService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            ChoiceChip(
              selected: !_useNewTopic,
              label: const Text('选择已有'),
              onSelected: (v) {
                setState(() => _useNewTopic = !v ? _useNewTopic : false);
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              selected: _useNewTopic,
              label: const Text('使用新主题'),
              onSelected: (v) {
                setState(() => _useNewTopic = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_useNewTopic)
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedTopicName != null &&
                    recordsService.topics.any((t) => t.name == _selectedTopicName)
                ? _selectedTopicName
                : null,
            items: [
              ...recordsService.topics.map((t) => DropdownMenuItem(
                    value: t.name,
                    child: Text(t.name),
                  )),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedTopicName = v);
            },
            decoration: const InputDecoration(labelText: '选择主题'),
          )
        else
          TextFormField(
            controller: _newTopicController,
            decoration: const InputDecoration(
              labelText: '输入新主题',
              hintText: '例如：学习/开发',
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _subTaskController,
          decoration: const InputDecoration(
            labelText: '子任务（可留空）',
            hintText: '例如：实现登录接口',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<PomodoroService>();
    final recordsService = context.watch<RecordsService>();

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
            _buildTopicSection(theme, recordsService),
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
                  onPressed: service.isRunning ? null : () => _handleStartPressed(service, context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始'),
                ),
                ElevatedButton.icon(
                  onPressed: service.isRunning && !service.isPaused
                      ? () async {
                          service.pause();
                          await context
                              .read<RecordsService>()
                              .updateOngoingRemainingSeconds(service.remaining.inSeconds);
                        }
                      : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('暂停'),
                ),
                ElevatedButton.icon(
                  onPressed: service.isRunning && service.isPaused ? service.resume : null,
                  icon: const Icon(Icons.play_circle),
                  label: const Text('继续'),
                ),
                Tooltip(
                  message: '清零界面倒计时，不影响未完成记录',
                  child: OutlinedButton.icon(
                    onPressed: () {
                      service.finishEarlyAndClear();
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('重置'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: (service.isRunning || service.isPaused)
                      ? () async {
                          final bool? ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('提前完成?'),
                              content: const Text('将写入当前时间为完成时间，并清零倒计时。'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            final int remainSecs = service.remaining.inSeconds;
                            await context.read<RecordsService>().finishOngoing(
                                  remainingSecondsAtFinish: remainSecs,
                                );
                            service.finishEarlyAndClear();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.flag_circle_outlined),
                  label: const Text('提前完成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
