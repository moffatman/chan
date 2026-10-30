/// Keep cached batch sets independent from their mutable source sets.
List<Set<int>> copyTreeStubBatches(Iterable<Set<int>> batches) =>
    [for (final batch in batches) batch.toSet()];

bool treeStubBatchesEqual(Iterable<Set<int>> a, Iterable<Set<int>> b) {
  final first = a.iterator;
  final second = b.iterator;
  while (first.moveNext()) {
    if (!second.moveNext() ||
        first.current.length != second.current.length ||
        !first.current.containsAll(second.current)) {
      return false;
    }
  }
  return !second.moveNext();
}

/// Inclusive, nondecreasing boundaries; the final batch is still open.
int treeBatchForId(List<int> splits, List<Set<int>> upgradedStubs, int id) {
  for (int i = 0; i < upgradedStubs.length; i++) {
    if (upgradedStubs[i].contains(id)) return i + 1;
  }
  int low = 0;
  int high = splits.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (id <= splits[middle]) {
      high = middle;
    } else {
      low = middle + 1;
    }
  }
  return low;
}
