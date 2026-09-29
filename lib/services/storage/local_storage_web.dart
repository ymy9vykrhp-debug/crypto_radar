import 'package:web/web.dart' as web;

import 'local_storage_base.dart';

LocalStorageBackend createLocalStorageBackend() => _WebLocalStorage();

class _WebLocalStorage implements LocalStorageBackend {
  @override
  Future<String?> read(String key) async {
    return web.window.localStorage.getItem(key);
  }

  @override
  Future<void> write(String key, String value) async {
    web.window.localStorage.setItem(key, value);
  }
}
