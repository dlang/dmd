/*
EXTRA_SOURCES: ../runnable/extra-files/paranoia.d
REQUIRED_ARGS: -o- -version=CTFE

ARG_SETS: -version=Single
ARG_SETS: -version=Double
ARG_SETS: -version=Extended

TODO: Achieve 0 defects/flaws!

TEST_OUTPUT:
----
0 failures
0 serious defects
$n$ defects/flaws
----
*/

module test.compilable.paranoia_ctfe;
