// EXTRA_SOURCES: imports/test15371.d

/*
TEST_OUTPUT:
---

---
*/

module test15371;

import imports.test15371;
import core.stdc.stdio;

void main() {
    auto test = new Test15371();
    const auto hasMember = __traits(hasMember, test, "privateField");
    if (hasMember) {
        printf("_traits(hasMember) found privateField\r\n");
    }
    auto field = __traits(getMember, test, "privateField");
    printf("Existing private field value: %d\r\n", field);
    field = 1;
    printf("New private field value: %d\r\n", field);
    auto overloads = __traits(getOverloads, test, "overload").length;
    printf("Found %d overloads for private method 'overload'\r\n", overloads);
    auto virtualMethods = __traits(getVirtualMethods, test, "overload").length;
    printf("Found %d virtual methods for private method 'overload'\r\n", virtualMethods);
    auto virtualFunctions = __traits(getVirtualFunctions, test, "overload").length;
    printf("Found %d virtual functions for private method 'overload'\r\n", virtualFunctions);
}
