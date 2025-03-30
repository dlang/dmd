/*
REQUIRED_ARGS: -conf=compilable/extra-files/empty.conf --help
PERMUTE_ARGS:
TEST_OUTPUT:
----
$r:DMD(32|64) D Compiler .*$
Copyright (C) 1999-$n$ by The D Language Foundation, All Rights Reserved written by Walter Bright

Documentation: https://dlang.org/
Config file: $p:compilable/extra-files/empty.conf$
Usage:
  dmd [<option>...] <file>...
  dmd [<option>...] -run <file> [<arg>...]

Where:
  <file>           D source file
  <arg>            Argument to pass when running the resulting program

<option>:
  @<cmdfile>       read arguments from cmdfile
$r:.*$
  -m64              generate 64 bit code
  -main             add default main() if not present already (e.g. for unittesting)
$r:.*$
----
*/
