import 'package:shared_preferences/shared_preferences.dart';

/// 暂留尚未迁走的菜单风格转换；页面布局不读取旧键或日夜分桶。
Future<void> migrateReaderSettings(SharedPreferences prefs) async {
  if (prefs.containsKey('readBarStyleFollowPage')) {
    if (!prefs.containsKey('readBarStyle')) {
      await prefs.setInt(
        'readBarStyle',
        prefs.getBool('readBarStyleFollowPage') == true ? 1 : 0,
      );
    }
    await prefs.remove('readBarStyleFollowPage');
  }
}
