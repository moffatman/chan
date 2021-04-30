extension SafeWhere<T> on Iterable<T> {
	T? tryFirstWhere(bool f(T v)) => this.cast<T?>().firstWhere((v) => f(v!), orElse: () => null);
}