import '../../bridge/transfer_dto.dart' as dto;
import '../../models/misc.dart';

// 书签查询、编辑与导出共用字段映射。— Codex + Bridge
Bookmark bookmarkFromDto(dto.BookmarkDto value) => Bookmark(
  id: value.id,
  time: value.time,
  bookName: value.bookName,
  bookAuthor: value.bookAuthor,
  chapterIndex: value.chapterIndex,
  chapterPos: value.chapterPos,
  chapterName: value.chapterName,
  bookText: value.bookText,
  content: value.content,
);

dto.BookmarkDto bookmarkToDto(Bookmark value) => dto.BookmarkDto(
  id: value.id,
  time: value.time,
  bookName: value.bookName,
  bookAuthor: value.bookAuthor,
  chapterIndex: value.chapterIndex,
  chapterPos: value.chapterPos,
  chapterName: value.chapterName,
  bookText: value.bookText,
  content: value.content,
);
