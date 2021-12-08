extension SafeWhere<T> on Iterable<T> {
	T? tryFirstWhere(bool Function(T v) f) => cast<T?>().firstWhere((v) => f(v!), orElse: () => null);
}