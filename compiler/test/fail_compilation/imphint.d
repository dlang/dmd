/*
TEST_OUTPUT:
---
fail_compilation/imphint.d(154): Error: `printf` is not defined, perhaps `import core.stdc.stdio;` is needed?
    printf("hello world\n");
    ^
fail_compilation/imphint.d(155): Error: `writeln` is not defined, perhaps `import std.stdio;` is needed?
    writeln("hello world\n");
    ^
fail_compilation/imphint.d(156): Error: `sin` is not defined, perhaps `import std.math;` is needed?
    sin(3.6);
    ^
fail_compilation/imphint.d(157): Error: `cos` is not defined, perhaps `import std.math;` is needed?
    cos(1.2);
    ^
fail_compilation/imphint.d(158): Error: `sqrt` is not defined, perhaps `import std.math;` is needed?
    sqrt(2.0);
    ^
fail_compilation/imphint.d(159): Error: `fabs` is not defined, perhaps `import std.math;` is needed?
    fabs(-3);
    ^
fail_compilation/imphint.d(162): Error: `AliasSeq` is not defined, perhaps `import std.meta;` is needed?
    AliasSeq();
    ^
fail_compilation/imphint.d(163): Error: `appender` is not defined, perhaps `import std.array;` is needed?
    appender();
    ^
fail_compilation/imphint.d(164): Error: `array` is not defined, perhaps `import std.array;` is needed?
    array();
    ^
fail_compilation/imphint.d(165): Error: `calloc` is not defined, perhaps `import core.stdc.stdlib;` is needed?
    calloc();
    ^
fail_compilation/imphint.d(166): Error: `chdir` is not defined, perhaps `import std.file;` is needed?
    chdir();
    ^
fail_compilation/imphint.d(167): Error: `dirEntries` is not defined, perhaps `import std.file;` is needed?
    dirEntries();
    ^
fail_compilation/imphint.d(168): Error: `drop` is not defined, perhaps `import std.range;` is needed?
    drop();
    ^
fail_compilation/imphint.d(169): Error: `each` is not defined, perhaps `import std.algorithm;` is needed?
    each();
    ^
fail_compilation/imphint.d(170): Error: `empty` is not defined, perhaps `import std.range;` is needed?
    empty();
    ^
fail_compilation/imphint.d(171): Error: `enumerate` is not defined, perhaps `import std.range;` is needed?
    enumerate();
    ^
fail_compilation/imphint.d(172): Error: `endsWith` is not defined, perhaps `import std.algorithm;` is needed?
    endsWith();
    ^
fail_compilation/imphint.d(173): Error: `enforce` is not defined, perhaps `import std.exception;` is needed?
    enforce();
    ^
fail_compilation/imphint.d(174): Error: `equal` is not defined, perhaps `import std.algorithm;` is needed?
    equal();
    ^
fail_compilation/imphint.d(175): Error: `exists` is not defined, perhaps `import std.file;` is needed?
    exists();
    ^
fail_compilation/imphint.d(176): Error: `filter` is not defined, perhaps `import std.algorithm;` is needed?
    filter();
    ^
fail_compilation/imphint.d(177): Error: `format` is not defined, perhaps `import std.format;` is needed?
    format();
    ^
fail_compilation/imphint.d(178): Error: `free` is not defined, perhaps `import core.stdc.stdlib;` is needed?
    free();
    ^
fail_compilation/imphint.d(179): Error: `front` is not defined, perhaps `import std.range;` is needed?
    front();
    ^
fail_compilation/imphint.d(180): Error: `iota` is not defined, perhaps `import std.range;` is needed?
    iota();
    ^
fail_compilation/imphint.d(181): Error: `isDir` is not defined, perhaps `import std.file;` is needed?
    isDir();
    ^
fail_compilation/imphint.d(182): Error: `isFile` is not defined, perhaps `import std.file;` is needed?
    isFile();
    ^
fail_compilation/imphint.d(183): Error: `join` is not defined, perhaps `import std.array;` is needed?
    join();
    ^
fail_compilation/imphint.d(184): Error: `joiner` is not defined, perhaps `import std.algorithm;` is needed?
    joiner();
    ^
fail_compilation/imphint.d(185): Error: `malloc` is not defined, perhaps `import core.stdc.stdlib;` is needed?
    malloc();
    ^
fail_compilation/imphint.d(186): Error: `map` is not defined, perhaps `import std.algorithm;` is needed?
    map();
    ^
fail_compilation/imphint.d(187): Error: `max` is not defined, perhaps `import std.algorithm;` is needed?
    max();
    ^
fail_compilation/imphint.d(188): Error: `min` is not defined, perhaps `import std.algorithm;` is needed?
    min();
    ^
fail_compilation/imphint.d(189): Error: `mkdir` is not defined, perhaps `import std.file;` is needed?
    mkdir();
    ^
fail_compilation/imphint.d(190): Error: `popFront` is not defined, perhaps `import std.range;` is needed?
    popFront();
    ^
fail_compilation/imphint.d(191): Error: `realloc` is not defined, perhaps `import core.stdc.stdlib;` is needed?
    realloc();
    ^
fail_compilation/imphint.d(192): Error: `replace` is not defined, perhaps `import std.array;` is needed?
    replace();
    ^
fail_compilation/imphint.d(193): Error: `rmdir` is not defined, perhaps `import std.file;` is needed?
    rmdir();
    ^
fail_compilation/imphint.d(194): Error: `sort` is not defined, perhaps `import std.algorithm;` is needed?
    sort();
    ^
fail_compilation/imphint.d(195): Error: `split` is not defined, perhaps `import std.array;` is needed?
    split();
    ^
fail_compilation/imphint.d(196): Error: `startsWith` is not defined, perhaps `import std.algorithm;` is needed?
    startsWith();
    ^
fail_compilation/imphint.d(197): Error: `take` is not defined, perhaps `import std.range;` is needed?
    take();
    ^
fail_compilation/imphint.d(198): Error: `text` is not defined, perhaps `import std.conv;` is needed?
    text();
    ^
fail_compilation/imphint.d(199): Error: `to` is not defined, perhaps `import std.conv;` is needed?
    to();
    ^
fail_compilation/imphint.d(201): Error: `InterpolationHeader` is not defined, perhaps `import core.interpolation;` ?
    void heresy(Args...)(InterpolationHeader header, Args args, InterpolationFooter footer) {}
         ^
fail_compilation/imphint.d(202): Error: template `heresy` is not callable using argument types `!()(InterpolationHeader, InterpolationFooter)`
    heresy(i"");
          ^
fail_compilation/imphint.d(201):        Candidate is: `heresy(Args...)(InterpolationHeader header, Args args, InterpolationFooter footer)`
    void heresy(Args...)(InterpolationHeader header, Args args, InterpolationFooter footer) {}
         ^
---
*/





void foo()
{
    printf("hello world\n");
    writeln("hello world\n");
    sin(3.6);
    cos(1.2);
    sqrt(2.0);
    fabs(-3);


    AliasSeq();
    appender();
    array();
    calloc();
    chdir();
    dirEntries();
    drop();
    each();
    empty();
    enumerate();
    endsWith();
    enforce();
    equal();
    exists();
    filter();
    format();
    free();
    front();
    iota();
    isDir();
    isFile();
    join();
    joiner();
    malloc();
    map();
    max();
    min();
    mkdir();
    popFront();
    realloc();
    replace();
    rmdir();
    sort();
    split();
    startsWith();
    take();
    text();
    to();

    void heresy(Args...)(InterpolationHeader header, Args args, InterpolationFooter footer) {}
    heresy(i"");
}
