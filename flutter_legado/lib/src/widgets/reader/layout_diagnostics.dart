/// 只在显式注入时记录文字测量路径耗时，正常阅读不启动计时器。
/// 包含 TextPainter 构造、布局和簇盒提取；不包含全部行度量与绘制成本。
class ReaderLayoutDiagnostics {
  int measurementCalls = 0;
  int measurementMicroseconds = 0;
  int ffiCalls = 0;
  int encodingMicroseconds = 0;
  int callMicroseconds = 0;
  int decodingMicroseconds = 0;
  int rustMicroseconds = 0;

  Stopwatch beginMeasurement() => Stopwatch()..start();

  void endMeasurement(Stopwatch watch) {
    watch.stop();
    measurementCalls++;
    measurementMicroseconds += watch.elapsedMicroseconds;
  }
}
