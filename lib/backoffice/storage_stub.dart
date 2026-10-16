// Off the web: kept in memory for the run (Android/iOS rely on the shared
// database for anything that must last).
final _mem = <String, String>{};

String? load(String key) => _mem[key];
void save(String key, String value) => _mem[key] = value;
void clear(String key) => _mem.remove(key);
