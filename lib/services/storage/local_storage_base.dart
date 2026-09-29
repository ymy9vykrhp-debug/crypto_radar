abstract interface class LocalStorageBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}
