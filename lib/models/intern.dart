final _internCache = <String>{};
// TODO: Some sort of cleaning up
String intern(String string) {
	final cached = _internCache.lookup(string);
	if (cached != null) {
		return cached;
	}
	_internCache.add(string);
	return string;
}