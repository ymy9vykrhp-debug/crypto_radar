import 'local_storage_base.dart';
import 'local_storage_io.dart'
    if (dart.library.js_interop) 'local_storage_web.dart'
    as implementation;

export 'local_storage_base.dart';

LocalStorageBackend createLocalStorageBackend() {
  return implementation.createLocalStorageBackend();
}
