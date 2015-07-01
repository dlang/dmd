module imports.test11595a;
import imports.test11595b;

struct Foo{}

static assert([__traits(allMembers, imports.test11595b)] == ["object", "Bar"]);