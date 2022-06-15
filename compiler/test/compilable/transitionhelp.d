/*
ARG_SETS: -transition=?
ARG_SETS: -transition=h
TEST_OUTPUT:
----
Language transitions listed by -transition=name:
  =all              Enables all available language transitions
  =field            list all non-mutable fields which occupy an object instance
  =complex          give deprecation messages about all usages of complex or imaginary types [DEPRECATED]
  =tls              list all variables going into thread local storage
  =in               list all usages of 'in' on parameter
  =inScope          list places where `in` parameters risk breaking code written before `in` implied `scope` (https://issues.dlang.org/show_bug.cgi?id=23175)
----
*/
