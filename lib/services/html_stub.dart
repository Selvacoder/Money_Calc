class Window {
  LocalStorage get localStorage => LocalStorage();
}

class LocalStorage {
  final Map<String, String> _data = {};
  Iterable<String> get keys => _data.keys;
  String? getItem(String key) => _data[key];
  void setItem(String key, String value) => _data[key] = value;
  void removeItem(String key) => _data.remove(key);
  void clear() => _data.clear();
}

final window = Window();
