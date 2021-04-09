// REQUIRED_ARGS: -Icompilable/imports
module issue16044; // https://issues.dlang.org/show_bug.cgi?id=16044

import pkg16044;
import pkg16044.sub;

static assert([__traits(allMembers, pkg16044)] == ["object", "test1", "test2"]);
static assert([__traits(allMembers, pkg16044.sub)] == ["object", "test3", "test4"]);
