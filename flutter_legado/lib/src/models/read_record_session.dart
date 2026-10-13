/// 原始持久化阅读会话，章节序号不表示字数。— Codex + UI
class ReadRecordSession {
  final int id;
  final String deviceId, bookName, author, bookUrl;
  final int startTime, endTime, chapterIndex;
  const ReadRecordSession({
    required this.id,
    this.deviceId = '',
    required this.bookName,
    required this.author,
    this.bookUrl = '',
    required this.startTime,
    required this.endTime,
    this.chapterIndex = 0,
  });
  int get durationMs => endTime - startTime;
  factory ReadRecordSession.fromJson(Map<String, dynamic> json) =>
      ReadRecordSession(
        id: (json['id'] as num).toInt(),
        deviceId: json['deviceId'] as String,
        bookName: json['bookName'] as String,
        author: json['author'] as String,
        bookUrl: json['bookUrl'] as String,
        startTime: (json['startTime'] as num).toInt(),
        endTime: (json['endTime'] as num).toInt(),
        chapterIndex: (json['chapterIndex'] as num).toInt(),
      );
  ReadRecordSession withInterval(int id, int start, int end) =>
      ReadRecordSession(
        id: id,
        deviceId: deviceId,
        bookName: bookName,
        author: author,
        bookUrl: bookUrl,
        startTime: start,
        endTime: end,
        chapterIndex: chapterIndex,
      );
}
