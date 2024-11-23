/*
TEST_OUTPUT:
---
fail_compilation/fail2656.d(49): Error: octal literals `0123` are no longer supported, use `std.conv.octal!"123"` instead
auto a = 0123;
         ^
fail_compilation/fail2656.d(50): Error: octal literals `01000000000000000000000` are no longer supported, use `std.conv.octal!"1000000000000000000000"` instead
auto b = 01000000000000000000000;
         ^
fail_compilation/fail2656.d(51): Error: octal literals `0100000L` are no longer supported, use `std.conv.octal!"100000L"` instead
auto c = 0100000L;
         ^
fail_compilation/fail2656.d(52): Error: octal literals `01777777777777777777777u` are no longer supported, use `std.conv.octal!"1777777777777777777777u"` instead
auto d = 01777777777777777777777u;
         ^
fail_compilation/fail2656.d(53): Error: octal literals `017777777777uL` are no longer supported, use `std.conv.octal!"17777777777uL"` instead
auto e = 017777777777uL;
         ^
fail_compilation/fail2656.d(54): Error: octal literals `0177777` are no longer supported, use `std.conv.octal!"177777"` instead
auto f = 0177777;
         ^
fail_compilation/fail2656.d(55): Error: octal literals `020000000000L` are no longer supported, use `std.conv.octal!"20000000000L"` instead
auto g = 020000000000L;
         ^
fail_compilation/fail2656.d(56): Error: octal literals `0200000u` are no longer supported, use `std.conv.octal!"200000u"` instead
auto h = 0200000u;
         ^
fail_compilation/fail2656.d(57): Error: octal literals `037777777777uL` are no longer supported, use `std.conv.octal!"37777777777uL"` instead
auto i = 037777777777uL;
         ^
fail_compilation/fail2656.d(58): Error: octal literals `040000000000` are no longer supported, use `std.conv.octal!"40000000000"` instead
auto j = 040000000000;
         ^
fail_compilation/fail2656.d(59): Error: octal literals `0777777777777777777777L` are no longer supported, use `std.conv.octal!"777777777777777777777L"` instead
auto k = 0777777777777777777777L;
         ^
fail_compilation/fail2656.d(60): Error: octal literals `077777u` are no longer supported, use `std.conv.octal!"77777u"` instead
auto l = 077777u;
         ^
fail_compilation/fail2656.d(61): Error: octal literals `077777uL` are no longer supported, use `std.conv.octal!"77777uL"` instead
auto m = 077777uL;
         ^
fail_compilation/fail2656.d(62): Error: octal literals `077777uL` are no longer supported, use `std.conv.octal!"77777uL"` instead
auto n = 0_7_7_7_7_7uL;
         ^
---
*/

auto a = 0123;
auto b = 01000000000000000000000;
auto c = 0100000L;
auto d = 01777777777777777777777u;
auto e = 017777777777uL;
auto f = 0177777;
auto g = 020000000000L;
auto h = 0200000u;
auto i = 037777777777uL;
auto j = 040000000000;
auto k = 0777777777777777777777L;
auto l = 077777u;
auto m = 077777uL;
auto n = 0_7_7_7_7_7uL;
