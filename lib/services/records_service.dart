import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/tomato_models.dart';
import 'storage_service.dart';

/// 负责番茄记录的业务逻辑：
/// - 按主题与子任务创建记录
/// - 完成时写入结束时间
/// - 重置时取消未完成记录
class RecordsService extends ChangeNotifier {
  RecordsService();

  final StorageService _storage = StorageService.instance;

  TomatoRecord? _ongoing; // 当前进行中的记录

  TomatoRecord? get ongoing => _ongoing;

  List<Topic> get topics => _storage.topics;
  List<TomatoRecord> get records => _storage.records;

  /// 启动时加载存储，供页面初次进入时直接读取列表
  Future<void> init() async {
    await _storage.ensureLoaded();
    notifyListeners();
  }

  /// 确保存在该名称的主题，不存在则创建。
  Future<Topic> _ensureTopic(String topicName) async {
    await _storage.ensureLoaded();
    final Topic? found = _storage.topics.firstWhere(
      (t) => t.name == topicName,
      orElse: () => Topic(id: '', name: ''),
    );
    if (found != null && found.id.isNotEmpty) return found;
    return _storage.addNewTopicByName(topicName);
  }

  /// 开始一条番茄记录。若已存在进行中记录则直接返回。
  Future<void> startSession({
    required String topicName,
    String? subTask,
    required int durationMinutes,
  }) async {
    if (_ongoing != null) return;
    final Topic topic = await _ensureTopic(topicName.trim().isEmpty ? '日常' : topicName.trim());
    final TomatoRecord record = TomatoRecord(
      id: _genId(),
      topicId: topic.id,
      topicNameSnapshot: topic.name,
      subTask: (subTask != null && subTask.trim().isNotEmpty) ? subTask.trim() : null,
      startAt: DateTime.now(),
      endAt: null,
      durationMinutes: durationMinutes,
    );
    await _storage.addRecord(record);
    await _storage.setLastTopicName(topic.name);
    _ongoing = record;
    notifyListeners();
    developer.log('Session started: ${record.id}', name: 'RecordsService');
  }

  /// 结束当前进行中的记录。
  Future<void> finishOngoing() async {
    if (_ongoing == null) return;
    final TomatoRecord updated = _ongoing!.copyWith(endAt: DateTime.now());
    await _storage.upsertRecord(updated);
    _ongoing = null;
    notifyListeners();
    developer.log('Session finished', name: 'RecordsService');
  }

  String? get lastTopicName => _storage.lastTopicName;

  Future<int> clearUnfinished({String? topicId}) => _storage.clearUnfinished(topicId: topicId);

  /// 取消并删除当前未完成的记录。
  Future<void> cancelOngoing() async {
    if (_ongoing == null) return;
    final TomatoRecord rec = _ongoing!;
    await _storage.deleteRecordById(rec.id);
    _ongoing = null;
    notifyListeners();
    developer.log('Session canceled', name: 'RecordsService');
  }

  String _genId() {
    final int ts = DateTime.now().microsecondsSinceEpoch;
    return 'rec_$ts';
  }
}


