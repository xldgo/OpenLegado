/// 真实每日单书阅读明细；虚拟排版内容和搜索过滤不参与统计。— Codex + UI
class ReadRecordDetail {
  final String bookName;
  final String author;
  final String date;
  final int readTime;
  final int lastRead;

  const ReadRecordDetail({
    required this.bookName,
    required this.author,
    required this.date,
    required this.readTime,
    this.lastRead = 0,
  });

  factory ReadRecordDetail.fromJson(Map<String, dynamic> json) =>
      ReadRecordDetail(
        bookName: json['bookName'] as String,
        author: json['author'] as String,
        date: json['date'] as String,
        readTime: (json['readTime'] as num).toInt(),
        lastRead: (json['lastRead'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'bookName': bookName,
    'author': author,
    'date': date,
    'readTime': readTime,
    'lastRead': lastRead,
  };

  @override
  bool operator ==(Object other) =>
      other is ReadRecordDetail &&
      bookName == other.bookName &&
      author == other.author &&
      date == other.date &&
      readTime == other.readTime &&
      lastRead == other.lastRead;

  @override
  int get hashCode => Object.hash(bookName, author, date, readTime, lastRead);
}
