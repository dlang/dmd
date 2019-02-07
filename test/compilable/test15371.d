module compilable.test15371;

import imports.test15371_types : type_test15371;
import core.stdc.stdio;

version(unittest)

void main() {
    printf(__traits(hasMember, type_test15371, "privateField"));
    printf(__traits(getMember, type_test15371, "privateField"));
    printf(__traits(getOverloads, type_test15371, "overload"));
    printf(__traits(getVirtualMethods, type_test15371));
    printf(__traits(getVirtualFunctions, type_test15371));
}
