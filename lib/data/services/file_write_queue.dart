class FileWriteQueue {
  final Map<String, Future<void>> _queues = {};

  Future<T> run<T>(String key, Future<T> Function() action) {
    final prev = _queues[key] ?? Future<void>.value();
    final completer = prev.then((_) => action());
    _queues[key] = completer.then((_) {}, onError: (_) {});
    return completer;
  }
}

