module compilable.test15371;

import imports.test15371_types : type_test15371;
import std.stdio: writeln;

version(unittest)

void main() {
    static foreach(m; __traits(allMembers, type_test15371)) {
        writeln(__traits(getMember, m));
    }
}
