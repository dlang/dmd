// REQUIRED_ARGS: -o-
// EXTRA_SOURCES: imports/a13465.d
/*
TEST_OUTPUT:
---
fail_compilation/imports/a13465.d(10): Error: cannot infer type from template instance `isMaskField!()`
    enum isMatchingMaskField = isMaskField!();
                               ^
fail_compilation/ice13465a.d(21): Error: template instance `imports.a13465.isMatchingMaskField!()` error instantiating
    enum b = isMatchingMaskField!();
             ^
---
*/

module ice13465a;

import imports.a13465;

auto createCheckpointMixins()
{
    enum b = isMatchingMaskField!();
}

immutable checkpointMixins = createCheckpointMixins;
