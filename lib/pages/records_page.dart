import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/records_service.dart';
import '../models/tomato_models.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  String _selectedTopicId = 'all';
  bool _ascending = true; // 默认按时间正序

  @override
  Widget build(BuildContext context) {
    final recordsService = context.watch<RecordsService>();
    final topics = recordsService.topics;
    final records = recordsService.records;

    final List<TomatoRecord> filtered = (_selectedTopicId == 'all'
            ? records
            : records.where((r) => r.topicId == _selectedTopicId))
        .toList();

    filtered.sort((a, b) => _ascending
        ? a.startAt.compareTo(b.startAt)
        : b.startAt.compareTo(a.startAt));

    final List<DropdownMenuItem<String>> topicItems = [
      const DropdownMenuItem(value: 'all', child: Text('全部主题')),
      ...topics.map(
        (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
      ),
    ];

    final int finishedCount = filtered.where((r) => r.isFinished).length;
    final int totalMinutes = filtered.where((r) => r.isFinished).fold(0, (acc, r) => acc + r.durationMinutes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('番茄记录'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('按主题查看：'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedTopicId,
                  items: topicItems,
                  onChanged: (v) => setState(() => _selectedTopicId = v ?? 'all'),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('清理未完成'),
                  onPressed: () async {
                    final String? tid = _selectedTopicId == 'all' ? null : _selectedTopicId;
                    final int removed = await recordsService.clearUnfinished(topicId: tid);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已清理 $removed 条未完成记录')),
                    );
                    setState(() {});
                  },
                ),
                const SizedBox(width: 12),
                Text('已完成番茄：$finishedCount'),
                const SizedBox(width: 16),
                Text('总时间（分钟）：$totalMinutes'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('主题')),
                    const DataColumn(label: Text('子任务')),
                    DataColumn(
                      label: Row(
                        children: [
                          const Text('开始时间'),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => setState(() => _ascending = !_ascending),
                            child: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const DataColumn(label: Text('结束时间')),
                    const DataColumn(label: Text('时长(分钟)')),
                  ],
                  rows: filtered.map((r) {
                    String fmt(DateTime? dt) {
                      if (dt == null) return '-';
                      final h = dt.hour.toString().padLeft(2, '0');
                      final m = dt.minute.toString().padLeft(2, '0');
                      final s = dt.second.toString().padLeft(2, '0');
                      return '$h:$m:$s';
                    }

                    return DataRow(cells: [
                      DataCell(Text(r.topicNameSnapshot)),
                      DataCell(Text(r.subTask ?? '')),
                      DataCell(Text(fmt(r.startAt))),
                      DataCell(Text(fmt(r.endAt))),
                      DataCell(Text(r.durationMinutes.toString())),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


