final _internCache = <String, String>{};
// TODO: Some sort of cleaning up
String intern(String string) => _internCache.putIfAbsent(string, () => string);