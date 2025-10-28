import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/tomato_models.dart';
import 'storage_service.dart';

/// 负责番茄记录的业务逻辑：
/// - 按主题与子任务创建记录
/// - 完成时写入结束时间
/// - 重置时仅重置剩余时间与开始时间，不删除记录
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
      remainingSeconds: durationMinutes * 60,
    );
    await _storage.addRecord(record);
    await _storage.setLastTopicName(topic.name);
    _ongoing = record;
    notifyListeners();
    developer.log('Session started: ${record.id}', name: 'RecordsService');
  }

  /// 结束当前进行中的记录。
  Future<void> finishOngoing({int? remainingSecondsAtFinish}) async {
    if (_ongoing == null) return;
    final TomatoRecord current = _ongoing!;
    final int totalSeconds = current.durationMinutes * 60;
    final int rawRemain = remainingSecondsAtFinish ?? 0;
    final int clampedRemain = rawRemain < 0
        ? 0
        : (rawRemain > totalSeconds ? totalSeconds : rawRemain);
    final TomatoRecord updated = current.copyWith(
      endAt: DateTime.now(),
      remainingSeconds: clampedRemain,
    );
    await _storage.upsertRecord(updated);
    _ongoing = null;
    notifyListeners();
    developer.log('Session finished, remainSecs=$clampedRemain', name: 'RecordsService');
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

  /// 重置当前进行中记录：更新开始时间为当前，
  /// 同步更新计划时长与剩余秒数为新的时长。
  Future<void> resetOngoingTo(Duration newDuration) async {
    if (_ongoing == null) return;
    final TomatoRecord updated = _ongoing!.copyWith(
      startAt: DateTime.now(),
      endAt: null,
      durationMinutes: newDuration.inMinutes,
      remainingSeconds: newDuration.inSeconds,
    );
    await _storage.upsertRecord(updated);
    _ongoing = updated;
    notifyListeners();
    developer.log('Ongoing reset to ${newDuration.inMinutes}m', name: 'RecordsService');
  }

  /// 删除一条记录（仅供记录页管理使用）。
  Future<void> deleteRecordById(String recordId) async {
    await _storage.deleteRecordById(recordId);
    if (_ongoing?.id == recordId) {
      _ongoing = null;
    }
    notifyListeners();
    developer.log('Record deleted: $recordId', name: 'RecordsService');
  }

  /// 暂停时更新当前进行中记录的剩余秒数。
  Future<void> updateOngoingRemainingSeconds(int seconds) async {
    if (_ongoing == null) return;
    final int clamped = seconds < 0 ? 0 : seconds;
    final TomatoRecord updated = _ongoing!.copyWith(remainingSeconds: clamped);
    await _storage.upsertRecord(updated);
    _ongoing = updated;
    notifyListeners();
    developer.log('Remaining seconds updated: $clamped', name: 'RecordsService');
  }

  /// 从记录列表继续一个未完成的任务。
  /// 若当前已有进行中记录，则直接返回不操作。
  Future<void> resumeRecordById(String recordId) async {
    if (_ongoing != null) return;
    await _storage.ensureLoaded();
    final TomatoRecord? rec = _storage.records.firstWhere(
      (r) => r.id == recordId,
      orElse: () => TomatoRecord(
        id: '',
        topicId: '',
        topicNameSnapshot: '',
        subTask: null,
        startAt: DateTime.now(),
        endAt: DateTime.now(),
        durationMinutes: 0,
        remainingSeconds: 0,
      ),
    );
    if (rec == null || rec.id.isEmpty || rec.endAt != null) return;
    _ongoing = rec;
    await _storage.setLastTopicName(rec.topicNameSnapshot);
    notifyListeners();
    developer.log('Resumed record: ${rec.id}', name: 'RecordsService');
  }

  String _genId() {
    final int ts = DateTime.now().microsecondsSinceEpoch;
    return 'rec_$ts';
  }

  /// 实际用时（秒）。规则：已完成时为 totalSeconds - remainingSeconds；夹在 [0, totalSeconds]。
  int computeActualSeconds(TomatoRecord record) {
    if (!record.isFinished) return 0;
    final int totalSeconds = record.durationMinutes * 60;
    int remain = record.remainingSeconds;
    if (remain < 0) remain = 0;
    if (remain > totalSeconds) remain = totalSeconds;
    return totalSeconds - remain;
  }

  /// 实际用时（分钟，向上取整）。
  int computeActualMinutesCeil(TomatoRecord record) {
    final int secs = computeActualSeconds(record);
    if (secs <= 0) return 0;
    return (secs + 59) ~/ 60;
  }
}


