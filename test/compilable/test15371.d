module compilable.test15371;

import imports.test15371_types : type_test15371;
import core.stdc.stdio;

version(unittest)

void main() {
    static foreach(m; __traits(allMembers, type_test15371)) {
        printf(__traits(getMember, m));
    }
}
