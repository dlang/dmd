module compilable.test15371;

import test15371_types : type_test15371;

version(unittest)

void main() {
    static foreach(m; __traits(allMembers, type_test15371)) {
        __traits(getMember, m);
    }
}
