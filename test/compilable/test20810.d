/*
REQUIRED_ARGS: --help
PERMUTE_ARGS:
TEST_OUTPUT:
----
DMD64 D Compiler $r:.*$
Copyright (C) 1999-$n$ by The D Language Foundation, All Rights Reserved written by Walter Bright

Documentation: https://dlang.org/
Config file:
Usage:
  dmd [<option>...] <file>...
  dmd [<option>...] -run <file> [<arg>...]

Where:
  <file>           D source file
  <arg>            Argument to pass when running the resulting program

<option>:
  @<cmdfile>       read arguments from cmdfile
  -allinst          generate code for all template instantiations
  -betterC          omit generating some runtime information and helper functions
  -boundscheck=[on|safeonly|off]
                    bounds checks on, in @safe only, or off
  -c                compile only, do not link
  -check=[assert|bounds|in|invariant|out|switch][=[on|off]]
                    enable or disable specific checks
  -check=[h|help|?] list information on all available checks
  -checkaction=[D|C|halt|context]
                    behavior on assert/boundscheck/finalswitch failure
  -checkaction=[h|help|?]
                    list information on all available check actions
  -color            turn colored console output on
  -color=[on|off|auto]
                    force colored console output on or off, or only when not redirected (default)
  -conf=<filename>  use config file at filename
  -cov              do code coverage analysis
  -cov=<nnn>        require at least nnn% code coverage
  -D                generate documentation
  -Dd<directory>    write documentation file to directory
  -Df<filename>     write documentation file to filename
  -d                silently allow deprecated features and symbols
  -de               issue an error when deprecated features or symbols are used (halt compilation)
  -dw               issue a message when deprecated features or symbols are used (default)
  -debug            compile in debug code
  -debug=<level>    compile in debug code <= level
  -debug=<ident>    compile in debug code identified by ident
  -debuglib=<name>  set symbolic debug library to name
  -defaultlib=<name>
                    set default library to name
  -deps             print module dependencies (imports/file/version/debug/lib)
  -deps=<filename>  write module dependencies to filename (only imports)
  -extern-std=<standard>
                    set C++ name mangling compatibility with <standard>
  -extern-std=[h|help|?]
                    list all supported standards
  -fPIC             generate position independent code
  -g                add symbolic debug info
  -gf               emit debug info for all referenced types
  -gs               always emit stack frame
  -gx               add stack stomp code
  -H                generate 'header' file
  -Hd=<directory>   write 'header' file to directory
  -Hf=<filename>    write 'header' file to filename
  -HC               generate C++ 'header' file
  -HCd=<directory>  write C++ 'header' file to directory
  -HCf=<filename>   write C++ 'header' file to filename
  --help            print help and exit
  -I=<directory>    look for imports also in directory
  -i[=<pattern>]    include imported modules in the compilation
  -ignore           ignore unsupported pragmas
  -inline           do function inlining
  -J=<directory>    look for string imports also in directory
  -L=<linkerflag>   pass linkerflag to link
  -lib              generate library rather than object files
  -lowmem           enable garbage collection for the compiler
  -m32              generate 32 bit code
  -m64              generate 64 bit code
  -main             add default main() (e.g. for unittesting)
  -man              open web browser on manual page
  -map              generate linker .map file
  -mcpu=<id>        generate instructions for architecture identified by 'id'
  -mcpu=[h|help|?]  list all architecture options
  -mixin=<filename> expand and save mixins to file specified by <filename>
  -mv=<package.module>=<filespec>
                    use <filespec> as source file for <package.module>
  -noboundscheck    no array bounds checking (deprecated, use -boundscheck=off)
  -O                optimize
  -o-               do not write object file
  -od=<directory>   write object & library files to directory
  -of=<filename>    name output file to filename
  -op               preserve source path for output files
  -preview=<id>     enable an upcoming language change identified by 'id'
  -preview=[h|help|?]
                    list all upcoming language changes
  -profile          profile runtime performance of generated code
  -profile=gc       profile runtime allocations
  -release          compile release version
  -revert=<id>      revert language change identified by 'id'
  -revert=[h|help|?]
                    list all revertable language changes
  -run <srcfile>    compile, link, and run the program srcfile
  -shared           generate shared library (DLL)
  -transition=<id>  help with language change identified by 'id'
  -transition=[h|help|?]
                    list all language changes
  -unittest         compile in unit tests
  -v                verbose
  -vcolumns         print character (column) numbers in diagnostics
  -verror-style=[digitalmars|gnu]
                    set the style for file/line number annotations on compiler messages
  -verrors=<num>    limit the number of error messages (0 means unlimited)
  -verrors=context  show error messages with the context of the erroring source line
  -verrors=spec     show errors from speculative compiles such as __traits(compiles,...)
  --version         print compiler version and exit
  -version=<level>  compile in version code >= level
  -version=<ident>  compile in version code identified by ident
  -vgc              list all gc allocations including hidden ones
  -vtls             list all variables going into thread local storage
  -w                warnings as errors (compilation will halt)
  -wi               warnings as messages (compilation will continue)
  -X                generate JSON file
  -Xf=<filename>    write JSON file to filename
  -Xcc=<driverflag> pass driverflag to linker driver (cc)
----
*/
