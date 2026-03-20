class RoomModel {
  final String id;
  final String code;
  final String hostUserId;
  final bool gameStarted;
  final int? gameSeed;

  RoomModel({
    required this.id,
    required this.code,
    required this.hostUserId,
    required this.gameStarted,
    required this.gameSeed,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'].toString(),
      code: json['code'] as String,
      hostUserId: json['host_user_id'].toString(),
      gameStarted: json['game_started'] as bool? ?? false,
      gameSeed: json['game_seed'] as int?,
    );
  }
}

class RoomPlayerModel {
  final String roomId;
  final String userId;
  final String playerName;
  final bool ready;
  final bool started;
  final bool finished;
  final int correctCount;
  final int? totalTimeMs;

  RoomPlayerModel({
    required this.roomId,
    required this.userId,
    required this.playerName,
    required this.ready,
    required this.started,
    required this.finished,
    required this.correctCount,
    required this.totalTimeMs,
  });

  factory RoomPlayerModel.fromJson(Map<String, dynamic> json) {
    return RoomPlayerModel(
      roomId: json['room_id'].toString(),
      userId: json['user_id'].toString(),
      playerName: json['player_name'] as String,
      ready: json['ready'] as bool? ?? false,
      started: json['started'] as bool? ?? false,
      finished: json['finished'] as bool? ?? false,
      correctCount: json['correct_count'] as int? ?? 0,
      totalTimeMs: json['total_time_ms'] as int?,
    );
  }
}

