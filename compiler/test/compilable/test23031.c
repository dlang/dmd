/* https://issues.dlang.org/show_bug.cgi?id=23031
 */

_Static_assert(sizeof("\x1") == 2, "1");
_Static_assert(sizeof("\x20") == 2, "2");
_Static_assert(sizeof("\x020") == 2, "3");
_Static_assert(sizeof("\x0020") == 2, "4");

_Static_assert("\x1"[0] == 1, "5");
_Static_assert("\x20"[0] == 0x20, "6");
_Static_assert("\x020"[0] == 0x20, "7");
_Static_assert("\x0020"[0] == 0x20, "8");
