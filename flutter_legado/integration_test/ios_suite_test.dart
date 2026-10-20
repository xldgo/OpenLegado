// iOS共用测试入口，复用一次宿主构建与安装；两个用例保留各自的断言。
import 'launcher_icon_ios_test.dart' as launcher_icon;
import 'e2e_search_read_ios_test.dart' as reading;

void main() {
  launcher_icon.main();
  reading.main();
}
