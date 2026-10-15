/// 正文标注，位置与样式沿用现有Rust契约。— Codex + Bridge
final class BookHighlight {
  const BookHighlight({
    this.time = 0,
    this.bookUrl = '',
    this.chapterUrl = '',
    this.bookName = '',
    this.bookAuthor = '',
    this.chapterIndex = 0,
    this.chapterPos = 0,
    this.chapterPosEnd = 0,
    this.layoutTitleLength = -1,
    this.chapterName = '',
    this.bookText = '',
    this.style = '',
    this.note = '',
  });

  final int time;
  final String bookUrl;
  final String chapterUrl;
  final String bookName;
  final String bookAuthor;
  final int chapterIndex;
  final int chapterPos;
  final int chapterPosEnd;
  final int layoutTitleLength;
  final String chapterName;
  final String bookText;
  final String style;
  final String note;

  factory BookHighlight.fromJson(Map<String, dynamic> json) => BookHighlight(
    time: json['time'] as int,
    bookUrl: json['bookUrl'] as String? ?? '',
    chapterUrl: json['chapterUrl'] as String? ?? '',
    bookName: json['bookName'] as String? ?? '',
    bookAuthor: json['bookAuthor'] as String? ?? '',
    chapterIndex: json['chapterIndex'] as int? ?? 0,
    chapterPos: json['chapterPos'] as int? ?? 0,
    chapterPosEnd: json['chapterPosEnd'] as int? ?? 0,
    layoutTitleLength: json['layoutTitleLength'] as int? ?? -1,
    chapterName: json['chapterName'] as String? ?? '',
    bookText: json['bookText'] as String? ?? '',
    style: json['style'] as String? ?? '',
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'time': time,
    'bookUrl': bookUrl,
    'chapterUrl': chapterUrl,
    'bookName': bookName,
    'bookAuthor': bookAuthor,
    'chapterIndex': chapterIndex,
    'chapterPos': chapterPos,
    'chapterPosEnd': chapterPosEnd,
    'layoutTitleLength': layoutTitleLength,
    'chapterName': chapterName,
    'bookText': bookText,
    'style': style,
    'note': note,
  };

  BookHighlight copyWith({
    int? time,
    String? bookUrl,
    String? chapterUrl,
    String? bookName,
    String? bookAuthor,
    int? chapterIndex,
    int? chapterPos,
    int? chapterPosEnd,
    int? layoutTitleLength,
    String? chapterName,
    String? bookText,
    String? style,
    String? note,
  }) => BookHighlight(
    time: time ?? this.time,
    bookUrl: bookUrl ?? this.bookUrl,
    chapterUrl: chapterUrl ?? this.chapterUrl,
    bookName: bookName ?? this.bookName,
    bookAuthor: bookAuthor ?? this.bookAuthor,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterPos: chapterPos ?? this.chapterPos,
    chapterPosEnd: chapterPosEnd ?? this.chapterPosEnd,
    layoutTitleLength: layoutTitleLength ?? this.layoutTitleLength,
    chapterName: chapterName ?? this.chapterName,
    bookText: bookText ?? this.bookText,
    style: style ?? this.style,
    note: note ?? this.note,
  );
}
