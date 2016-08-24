// PERMUTE_ARGS:
import imports.imp15907d;

enum common = ["toString", "toHash", "opCmp", "opEquals", "Monitor", "factory"];
class Derived : Base
{
    static assert([__traits(allMembers, Derived)] == "a" ~ common);
}

// can't see protected members here
static assert([__traits(allMembers, Derived)] == common);
