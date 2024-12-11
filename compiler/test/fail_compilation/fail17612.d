/* TEST_OUTPUT:
---
fail_compilation/fail17612.d(20): Error: undefined identifier `string`
    string toString();
           ^
fail_compilation/fail17612.d(23): Error: `TypeInfo` not found. object.d may be incorrectly installed or corrupt.
class TypeInfo {}
^
fail_compilation/fail17612.d(23):        dmd might not be correctly installed. Run 'dmd -man' for installation instructions.
fail_compilation/fail17612.d(23):        config file: not found
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17612

module object;

class Object
{
    string toString();
}

class TypeInfo {}
