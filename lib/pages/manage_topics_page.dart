import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/records_service.dart';
import '../models/tomato_models.dart';
import '../services/storage_service.dart';

class ManageTopicsPage extends StatefulWidget {
  const ManageTopicsPage({super.key});

  @override
  State<ManageTopicsPage> createState() => _ManageTopicsPageState();
}

class _ManageTopicsPageState extends State<ManageTopicsPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<RecordsService>();
    final topics = records.topics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理主题'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: '新增主题',
                      hintText: '输入主题名称，例如：日常/学习/开发',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final String name = _controller.text.trim();
                    if (name.isEmpty) return;
                    await StorageService.instance.addNewTopicByName(name);
                    _controller.clear();
                    if (mounted) setState(() {});
                  },
                  child: const Text('新增'),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemBuilder: (_, idx) {
                  final Topic t = topics[idx];
                  return ListTile(
                    title: Text(t.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '重命名',
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final String? newName = await showDialog<String>(
                              context: context,
                              builder: (ctx) {
                                final TextEditingController c = TextEditingController(text: t.name);
                                return AlertDialog(
                                  title: const Text('重命名主题'),
                                  content: TextField(
                                    controller: c,
                                    decoration: const InputDecoration(labelText: '主题名称'),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('确定')),
                                  ],
                                );
                              },
                            );
                            if (newName != null && newName.isNotEmpty) {
                              await StorageService.instance.addOrUpdateTopic(t.copyWith(name: newName));
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                        IconButton(
                          tooltip: '删除主题及其记录',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final bool? ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('确认删除'),
                                content: const Text('删除主题将同时删除其所有番茄记录，确定继续？'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await StorageService.instance.deleteTopic(t.id);
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: topics.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


