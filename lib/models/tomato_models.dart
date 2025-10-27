import 'dart:convert';

/// 主题（Topic）模型。每个主题有唯一 id 与名称。
class Topic {
  Topic({required this.id, required this.name});

  final String id;
  final String name;

  Topic copyWith({String? id, String? name}) => Topic(
        id: id ?? this.id,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  static Topic fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

/// 番茄记录（TomatoRecord）
/// 一条记录绑定主题与可选子任务，含开始/结束时间和本次番茄的时长（分钟）。
class TomatoRecord {
  TomatoRecord({
    required this.id,
    required this.topicId,
    required this.topicNameSnapshot,
    required this.subTask,
    required this.startAt,
    this.endAt,
    required this.durationMinutes,
    required this.remainingSeconds,
  });

  final String id;
  final String topicId;
  final String topicNameSnapshot; // 冗余以便历史展示不受重命名影响
  final String? subTask; // 可为空
  final DateTime startAt; // 精确到秒
  final DateTime? endAt; // 完成后写入
  final int durationMinutes; // 本番茄设置的总时长（如 35/40）
  final int remainingSeconds; // 剩余秒数：默认=duration*60；暂停写入；完成=0

  bool get isFinished => endAt != null;

  TomatoRecord copyWith({
    String? id,
    String? topicId,
    String? topicNameSnapshot,
    String? subTask,
    DateTime? startAt,
    DateTime? endAt,
    int? durationMinutes,
    int? remainingSeconds,
  }) => TomatoRecord(
        id: id ?? this.id,
        topicId: topicId ?? this.topicId,
        topicNameSnapshot: topicNameSnapshot ?? this.topicNameSnapshot,
        subTask: subTask ?? this.subTask,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicId': topicId,
        'topicNameSnapshot': topicNameSnapshot,
        'subTask': subTask,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'remainingSeconds': remainingSeconds,
      };

  static TomatoRecord fromJson(Map<String, dynamic> json) => TomatoRecord(
        id: json['id'] as String,
        topicId: json['topicId'] as String,
        topicNameSnapshot: json['topicNameSnapshot'] as String,
        subTask: json['subTask'] as String?,
        startAt: DateTime.parse(json['startAt'] as String),
        endAt: json['endAt'] == null ? null : DateTime.parse(json['endAt'] as String),
        durationMinutes: (json['durationMinutes'] as num).toInt(),
        // 兼容老数据：未完成默认=duration*60；已完成=0
        remainingSeconds: json.containsKey('remainingSeconds')
            ? (json['remainingSeconds'] as num).toInt()
            : ((json['endAt'] == null)
                ? ((json['durationMinutes'] as num).toInt() * 60)
                : 0),
      );
}

/// 简单 JSON 列表编解码工具
class JsonListCodec<T> {
  JsonListCodec(this.encode, this.decode);

  final Map<String, dynamic> Function(T value) encode;
  final T Function(Map<String, dynamic> json) decode;

  String encodeList(List<T> list) => jsonEncode(list.map(encode).toList());
  List<T> decodeList(String? text) {
    if (text == null || text.isEmpty) return <T>[];
    final dynamic raw = jsonDecode(text);
    if (raw is! List) return <T>[];
    return raw.cast<Map<String, dynamic>>().map(decode).toList();
  }
}


