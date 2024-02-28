class ParentAndChildIdentifier {
	final int parentId;
	final int childId;
	const ParentAndChildIdentifier({
		required this.parentId,
		required this.childId
	});

	const ParentAndChildIdentifier.same(int id) : parentId = id, childId = id;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is ParentAndChildIdentifier) &&
		(other.parentId == parentId) &&
		(other.childId == childId);
	@override
	int get hashCode => Object.hash(parentId, childId);
	@override
	String toString() => 'ParentAndChildIdentifier(parentId: $parentId, childId: $childId)';
}