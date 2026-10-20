# 路由输入与结果清单

对应路由迁移R1，默认缺失参数沿用既有空态/新建页，Book必需的目录和编辑页回首页。
类型规范化仅改变内部传参方式，不改变用户行为。所有目标均有应用内入口；平台桥/通知等列于外部动作。

| 名称 | 路径 | 输入 | 返回 | 外部动作 |
|---|---|---|---|---|
| home | `/` | 无 | 关闭/调用方刷新 | 启动完成 |
| reader | `/reader` | Book/ReaderRouteArgs稳定身份 + 可选BookCoverOrigin（瞬时） | 关闭/调用方刷新 | 公共开书 |
| readerComic | `/reader-comic` | String书籍地址 | 关闭/调用方刷新 | — |
| search | `/search` | SearchRouteArgs | 关闭/调用方刷新 | — |
| sources | `/sources` | 无 | 关闭/调用方刷新 | — |
| sourceEdit | `/sources/edit` | BookSource? | bool/调用方刷新 | — |
| exploreShow | `/explore_show` | ExploreShowArgs? | 关闭/调用方刷新 | — |
| settings | `/settings` | 无 | 关闭/调用方刷新 | — |
| privacy | `/privacy` | 无 | 关闭/调用方刷新 | — |
| otherSettings | `/other_settings` | 无 | 关闭/调用方刷新 | — |
| cacheSettings | `/cache_settings` | 无 | 关闭/调用方刷新 | — |
| cacheDownloads | `/cache_downloads` | 无 | 关闭/调用方刷新 | — |
| offlineCache | `/offline_cache` | 无 | 关闭/调用方刷新 | — |
| rss | `/rss` | 无 | 关闭/调用方刷新 | — |
| ruleSub | `/rule_sub` | 无 | 关闭/调用方刷新 | — |
| audio | `/audio` | Book? | 关闭/调用方刷新 | 媒体通知 |
| bookInfo | `/book_info` | Book；URI稳定地址恢复Book快照 | 关闭/调用方刷新 | — |
| editBookInfo | `/edit_book_info` | Book，缺失回首页 | 关闭/调用方刷新 | — |
| changeSource | `/change_source` | Book? | String新书籍地址? | — |
| readingStats | `/reading_stats` | 无 | 关闭/调用方刷新 | — |
| readRecord | `/read_record` | 无 | 关闭/调用方刷新 | — |
| readRecordOverview | `/read_record_overview` | 无 | 关闭/调用方刷新 | — |
| bookmarks | `/bookmarks` | 无 | 关闭/调用方刷新 | — |
| replaceRules | `/replace_rules` | String预填规则? | 关闭/调用方刷新 | — |
| replaceRuleEdit | `/replace_rule_edit` | ReplaceRule或String预填规则? | bool是否保存? | — |
| autoTasks | `/auto_tasks` | AutoTaskRouteArgs | 关闭/调用方刷新 | — |
| sourceDebug | `/sources/debug` | String源地址? | 关闭/调用方刷新 | — |
| rssSourceEdit | `/rss/edit` | RssSource? | bool/调用方刷新 | — |
| readAloudConfig | `/read_aloud_config` | 无 | 关闭/调用方刷新 | — |
| readAloudSettings | `/read_aloud_settings` | 无 | 关闭/调用方刷新 | — |
| readAloudPlayer | `/read_aloud_player` | 通知Page使用当前播放会话；胶囊直接Route持瞬时锚点 | String阅读动作? | 媒体通知/胶囊 |
| themeConfig | `/theme_config` | 无 | 关闭/调用方刷新 | — |
| bottomBarSkin | `/bottom_bar_skin` | 无 | 关闭/调用方刷新 | — |
| importBooks | `/import_books` | 无 | 关闭/调用方刷新 | — |
| remoteBooks | `/remote_books` | 无 | 关闭/调用方刷新 | — |
| bookGroups | `/book_groups` | 无 | 关闭/调用方刷新 | — |
| bookshelfManage | `/bookshelf/manage` | 无 | 关闭/调用方刷新 | — |
| searchContent | `/search_content` | ContentSearchRouteArgs | 关闭/调用方刷新 | — |
| toc | `/toc` | Book，缺失回首页 | int章节索引? | — |
| about | `/about` | 无 | 关闭/调用方刷新 | — |
| appLog | `/app_log` | 无 | 关闭/调用方刷新 | — |
| rssSourceManage | `/rss/manage` | 无 | 关闭/调用方刷新 | — |
| rssFavorites | `/rss/favorites` | 无 | 关闭/调用方刷新 | — |
| rssSourceDebug | `/rss/source_debug` | String源地址? | 关闭/调用方刷新 | — |
| changeCover | `/change_cover` | Book? | String封面地址? | — |
| txtTocRules | `/txt_toc_rules` | 无 | 关闭/调用方刷新 | — |
| dict | `/dict` | 无 | 关闭/调用方刷新 | — |
| dictRule | `/dict_rule` | 无 | 关闭/调用方刷新 | — |
| fonts | `/fonts` | String目标(body/title) | 关闭/调用方刷新 | — |
| highlightRules | `/highlight_rules` | 无 | 关闭/调用方刷新 | — |
| fileManage | `/file_manage` | 无 | 关闭/调用方刷新 | — |
| qrcode | `/qrcode` | 无 | String扫码内容? | — |
| welcome | `/welcome` | 无 | 关闭/调用方刷新 | 冷启动 |
| welcomeConfig | `/welcome_config` | 无 | 关闭/调用方刷新 | — |
| browser | `/browser` | BrowserRouteArgs | 关闭/调用方刷新 | 平台打开网页 |
| video | `/video` | Book或VideoScreenArgs | 关闭/调用方刷新 | 平台播放/悬浮窗恢复 |
| webdavSettings | `/webdav_settings` | 无 | 关闭/调用方刷新 | — |

局部弹窗、RSS文章详情、导入确认和WebView登录等直接push的操作页保持局部导航，不新增命名路由。
legado/yuedu为导入动作，由既有DeepLinkService处理，不伪装成以上页面路径。
未知路由保持首页兜底，readingStats保留原阅读记录目标，不新增兼容历史数据层。

编写者：Codex + UI｜2026-10-19
