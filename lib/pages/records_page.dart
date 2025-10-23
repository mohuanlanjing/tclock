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

  @override
  Widget build(BuildContext context) {
    final recordsService = context.watch<RecordsService>();
    final topics = recordsService.topics;
    final records = recordsService.records;

    final List<TomatoRecord> filtered = (_selectedTopicId == 'all'
            ? records
            : records.where((r) => r.topicId == _selectedTopicId))
        .toList();

    final sections = _groupByDateDescThenSortAscWithin(filtered);

    final List<DropdownMenuItem<String>> topicItems = [
      const DropdownMenuItem(value: 'all', child: Text('全部主题')),
      ...topics.map(
        (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
      ),
    ];

    final int finishedCount = filtered.where((r) => r.isFinished).length;
    final int totalMinutes = filtered
        .where((r) => r.isFinished)
        .fold(0, (acc, r) => acc + r.durationMinutes);

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
              child: sections.isEmpty
                  ? const Center(child: Text('暂无记录'))
                  : ListView.builder(
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        final dateTitle = _formatDate(section.dateOnly);
                        final finishedInSection = section.records.where((r) => r.isFinished).length;
                        final minutesInSection = section.records
                            .where((r) => r.isFinished)
                            .fold(0, (acc, r) => acc + r.durationMinutes);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            title: Row(
                              children: [
                                Text(dateTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('完成 $finishedInSection · ${minutesInSection} 分钟'),
                                ),
                              ],
                            ),
                            children: [
                              const Divider(height: 1),
                              ...section.records.map((r) => _RecordTile(record: r)).toList(),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DateSection> _groupByDateDescThenSortAscWithin(List<TomatoRecord> list) {
    if (list.isEmpty) return const <_DateSection>[];
    final Map<DateTime, List<TomatoRecord>> dateToRecords = <DateTime, List<TomatoRecord>>{};
    for (final r in list) {
      final dt = r.startAt;
      final dateOnly = DateTime(dt.year, dt.month, dt.day);
      dateToRecords.putIfAbsent(dateOnly, () => <TomatoRecord>[]).add(r);
    }
    final dates = dateToRecords.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 日期倒序
    final List<_DateSection> sections = <_DateSection>[];
    for (final d in dates) {
      final records = dateToRecords[d]!..sort((a, b) => a.startAt.compareTo(b.startAt)); // 组内时间正序
      sections.add(_DateSection(dateOnly: d, records: List<TomatoRecord>.from(records)));
    }
    return sections;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final label = d == today ? '今天' : _weekdayZh(d.weekday);
    return '$y-$m-$dd · $label';
  }

  String _weekdayZh(int w) {
    switch (w) {
      case 1:
        return '周一';
      case 2:
        return '周二';
      case 3:
        return '周三';
      case 4:
        return '周四';
      case 5:
        return '周五';
      case 6:
        return '周六';
      case 7:
        return '周日';
      default:
        return '';
    }
  }
}

class _DateSection {
  const _DateSection({required this.dateOnly, required this.records});
  final DateTime dateOnly;
  final List<TomatoRecord> records;
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});
  final TomatoRecord record;

  @override
  Widget build(BuildContext context) {
    final start = _formatTime(record.startAt);
    final end = _formatTime(record.endAt);
    final title = record.subTask?.isNotEmpty == true ? record.subTask! : record.topicNameSnapshot;
    final subtitle = record.subTask?.isNotEmpty == true ? record.topicNameSnapshot : null;
    return ListTile(
      dense: true,
      leading: Icon(record.isFinished ? Icons.check_circle : Icons.timelapse, color: record.isFinished ? Colors.green : Colors.orange),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$start - $end', style: const TextStyle(fontFeatures: [])),
          const SizedBox(height: 2),
          Text('${record.durationMinutes} 分钟'),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}


