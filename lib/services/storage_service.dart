import 'dart:developer' as developer;

// no-op
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tomato_models.dart';

/// 本地存储服务：负责主题列表与番茄记录的持久化。
/// 使用 shared_preferences 简化实现，数据量较小时可行。
class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  static const String _keyTopics = 'topics_v1';
  static const String _keyRecords = 'records_v1';
  static const String _keyLastTopicName = 'last_topic_name_v1';

  final JsonListCodec<Topic> _topicCodec = JsonListCodec<Topic>((t) => t.toJson(), Topic.fromJson);
  final JsonListCodec<TomatoRecord> _recordCodec =
      JsonListCodec<TomatoRecord>((r) => r.toJson(), TomatoRecord.fromJson);

  List<Topic> _topicsCache = <Topic>[];
  List<TomatoRecord> _recordsCache = <TomatoRecord>[];
  bool _loaded = false;
  String? _lastTopicName;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _topicsCache = _topicCodec.decodeList(prefs.getString(_keyTopics));
      _recordsCache = _recordCodec.decodeList(prefs.getString(_keyRecords));
      _lastTopicName = prefs.getString(_keyLastTopicName);
      _loaded = true;
      if (_topicsCache.isEmpty) {
        // 默认主题：日常
        _topicsCache = <Topic>[Topic(id: _genId(), name: '日常')];
        await _persistTopics(prefs);
      }
    } catch (e, s) {
      developer.log('Failed to load storage: $e', name: 'StorageService', error: e, stackTrace: s);
      _topicsCache = <Topic>[Topic(id: _genId(), name: '日常')];
      _recordsCache = <TomatoRecord>[];
      _loaded = true;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _persistTopics(prefs);
      await _persistRecords(prefs);
    }
  }

  List<Topic> get topics => List.unmodifiable(_topicsCache);
  List<TomatoRecord> get records => List.unmodifiable(_recordsCache);

  Future<void> addOrUpdateTopic(Topic topic) async {
    await ensureLoaded();
    final int index = _topicsCache.indexWhere((t) => t.id == topic.id);
    if (index >= 0) {
      _topicsCache[index] = topic;
    } else {
      _topicsCache.add(topic);
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persistTopics(prefs);
  }

  Future<Topic> addNewTopicByName(String name) async {
    await ensureLoaded();
    final Topic? exists = _topicsCache.firstWhere(
      (t) => t.name == name,
      orElse: () => Topic(id: '', name: ''),
    );
    if (exists != null && exists.id.isNotEmpty) return exists;
    final Topic topic = Topic(id: _genId(), name: name);
    _topicsCache.add(topic);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persistTopics(prefs);
    return topic;
  }

  Future<void> deleteTopic(String topicId) async {
    await ensureLoaded();
    // 先找到名称用于维护最近主题
    final int idx = _topicsCache.indexWhere((t) => t.id == topicId);
    final String? deletedName = idx >= 0 ? _topicsCache[idx].name : null;
    _topicsCache.removeWhere((t) => t.id == topicId);
    _recordsCache.removeWhere((r) => r.topicId == topicId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persistTopics(prefs);
    await _persistRecords(prefs);
    if (deletedName != null && deletedName.isNotEmpty && _lastTopicName == deletedName) {
      _lastTopicName = null;
      await prefs.remove(_keyLastTopicName);
    }
  }

  Future<void> addRecord(TomatoRecord record) async {
    await ensureLoaded();
    _recordsCache.add(record);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persistRecords(prefs);
  }

  Future<void> upsertRecord(TomatoRecord record) async {
    await ensureLoaded();
    final int index = _recordsCache.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      _recordsCache[index] = record;
    } else {
      _recordsCache.add(record);
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persistRecords(prefs);
  }

  Future<void> deleteRecordById(String recordId) async {
    await ensureLoaded();
    _recordsCache.removeWhere((r) => r.id == recordId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persistRecords(prefs);
  }

  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _topicsCache.clear();
    _recordsCache.clear();
    await _persistTopics(prefs);
    await _persistRecords(prefs);
  }

  Future<void> _persistTopics(SharedPreferences prefs) async {
    await prefs.setString(_keyTopics, _topicCodec.encodeList(_topicsCache));
  }

  Future<void> _persistRecords(SharedPreferences prefs) async {
    await prefs.setString(_keyRecords, _recordCodec.encodeList(_recordsCache));
  }

  String _genId() {
    final int ts = DateTime.now().microsecondsSinceEpoch;
    return 'id_$ts';
  }

  String? get lastTopicName => _lastTopicName;

  Future<void> setLastTopicName(String name) async {
    await ensureLoaded();
    _lastTopicName = name;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastTopicName, name);
  }

  /// 批量清理未完成记录。传入 topicId 仅清理该主题，否则清理全部。
  Future<int> clearUnfinished({String? topicId}) async {
    await ensureLoaded();
    final int before = _recordsCache.length;
    _recordsCache.removeWhere((r) => r.endAt == null && (topicId == null || r.topicId == topicId));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persistRecords(prefs);
    return before - _recordsCache.length;
  }
}


