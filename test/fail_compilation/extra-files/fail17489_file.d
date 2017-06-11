struct Path {
		immutable()m_nodes;
}

enum DirectoryChangeType {}


struct DirectoryChange {
	DirectoryChangeType type;
	Path path;
}
