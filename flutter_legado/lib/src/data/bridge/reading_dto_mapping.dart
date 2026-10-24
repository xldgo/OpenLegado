import '../../bridge/transfer_dto.dart' as dto;
import '../../domain/models/book_highlight.dart';
import '../../domain/models/highlight_rule.dart';
import '../../models/misc.dart';
import '../../models/read_record_session.dart';

// 阅读域传输快照与现有领域模型逐字段适配，不做 JSON 往返。— Codex + Bridge

// 原 JSON 入口由 serde 拒绝超出 i32 的值；直接编码前同样拒绝，避免有符号截断。
int _int32(int value, String field) {
  if (value < -2147483648 || value > 2147483647) {
    throw RangeError.range(value, -2147483648, 2147483647, field);
  }
  return value;
}

ReadRecord readRecordFromDto(dto.ReadRecordDto value) => ReadRecord(
  bookName: value.bookName,
  author: value.author,
  readTime: value.readTime,
  lastRead: value.lastRead,
  deviceId: value.deviceId,
);

ReadRecordSession readRecordSessionFromDto(dto.ReadRecordSessionDto value) =>
    ReadRecordSession(
      id: value.id,
      deviceId: value.deviceId,
      bookName: value.bookName,
      author: value.author,
      bookUrl: value.bookUrl,
      startTime: value.startTime,
      endTime: value.endTime,
      chapterIndex: value.chapterIndex,
    );

BookGroup bookGroupFromDto(dto.BookGroupDto value) => BookGroup(
  groupId: value.groupId,
  groupName: value.groupName,
  cover: value.cover,
  order: value.order,
  show: value.show_,
  isPrivate: value.isPrivate,
);

BookHighlight bookHighlightFromDto(dto.BookHighlightDto value) => BookHighlight(
  time: value.time,
  bookUrl: value.bookUrl,
  chapterUrl: value.chapterUrl,
  bookName: value.bookName,
  bookAuthor: value.bookAuthor,
  chapterIndex: value.chapterIndex,
  chapterPos: value.chapterPos,
  chapterPosEnd: value.chapterPosEnd,
  layoutTitleLength: value.layoutTitleLength,
  chapterName: value.chapterName,
  bookText: value.bookText,
  style: value.style,
  note: value.note,
);

dto.BookHighlightDto bookHighlightToDto(BookHighlight value) =>
    dto.BookHighlightDto(
      time: value.time,
      bookUrl: value.bookUrl,
      chapterUrl: value.chapterUrl,
      bookName: value.bookName,
      bookAuthor: value.bookAuthor,
      chapterIndex: _int32(value.chapterIndex, 'chapterIndex'),
      chapterPos: _int32(value.chapterPos, 'chapterPos'),
      chapterPosEnd: _int32(value.chapterPosEnd, 'chapterPosEnd'),
      layoutTitleLength: _int32(value.layoutTitleLength, 'layoutTitleLength'),
      chapterName: value.chapterName,
      bookText: value.bookText,
      style: value.style,
      note: value.note,
    );

HighlightRule highlightRuleFromDto(dto.HighlightRuleDto value) => HighlightRule(
  id: value.id,
  uuid: value.uuid,
  name: value.name,
  pattern: value.pattern,
  isRegex: value.isRegex,
  scope: value.scope,
  isEnabled: value.isEnabled,
  style: value.style,
  sortOrder: value.sortOrder,
  timeoutMillisecond: value.timeoutMillisecond,
  applyToTitle: value.applyToTitle,
);

dto.HighlightRuleDto highlightRuleToDto(HighlightRule value) =>
    dto.HighlightRuleDto(
      id: value.id > 0 ? value.id : 0,
      uuid: value.uuid,
      name: value.name,
      pattern: value.pattern,
      isRegex: value.isRegex,
      scope: value.scope,
      isEnabled: value.isEnabled,
      style: value.style,
      sortOrder: _int32(value.sortOrder, 'sortOrder'),
      timeoutMillisecond: value.timeoutMillisecond,
      applyToTitle: value.applyToTitle,
    );
