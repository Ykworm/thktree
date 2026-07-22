/// 步骤级耗时统计工具，供集成测试使用。
///
/// 用法：
/// ```dart
/// final timer = StepTimer()..start();
/// timer.step('步骤名');
/// // ...
/// timer.finish();
/// ```
class StepRecord {
  final int index;
  final String name;
  final Duration elapsed;
  StepRecord(this.index, this.name, this.elapsed);
}

class StepTimer {
  final Stopwatch _stopwatch = Stopwatch();
  final List<StepRecord> _records = [];
  Duration _lastElapsed = Duration.zero;

  void start() => _stopwatch.start();

  void step(String name) {
    final now = _stopwatch.elapsed;
    final duration = now - _lastElapsed;
    _records.add(StepRecord(_records.length + 1, name, duration));
    _lastElapsed = now;
    // ignore: avoid_print
    print('[Step ${_records.length}] $name — ${_format(duration)}');
  }

  void finish() {
    _stopwatch.stop();
    // ignore: avoid_print
    print('───────────────────────────────────');
    // ignore: avoid_print
    print('总耗时: ${_format(_stopwatch.elapsed)}');
  }

  List<StepRecord> get steps => List.unmodifiable(_records);

  String _format(Duration d) {
    if (d.inSeconds >= 10) {
      return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${(d.inMilliseconds / 1000).toStringAsFixed(2)}s';
  }
}
