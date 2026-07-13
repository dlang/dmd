/*
REQUIRED_ARGS: -Xf- -o-
PERMUTE_ARGS:
TEST_OUTPUT:
----
[
 {
  "kind" : "module",
  "file" : "compilable$?:windows=\\|/$json18518.d",
  "members" : [
   {
    "kind" : "template",
    "protection" : "public",
    "line" : $n$,
    "char" : $n$,
    "name" : "Mix",
    "parameters" : [
     {
      "name" : "T",
      "kind" : "type"
     }
    ],
    "members" : [
     {
      "name" : "mixmember",
      "kind" : "variable",
      "line" : $n$,
      "char" : $n$,
      "type" : "T"
     }
    ]
   },
   {
    "name" : "S",
    "kind" : "struct",
    "protection" : "public",
    "line" : $n$,
    "char" : $n$,
    "members" : [
     {
      "name" : "Mix!int",
      "kind" : "mixin",
      "protection" : "public",
      "line" : $n$,
      "char" : $n$,
      "members" : [
       {
        "name" : "mixmember",
        "kind" : "variable",
        "protection" : "public",
        "line" : $n$,
        "char" : $n$,
        "deco" : "i",
        "originalType" : "T",
        "offset" : 0
       }
      ]
     }
    ]
   }
  ]
 }
]
----

https://github.com/dlang/dmd/issues/18518
*/

mixin template Mix(T)
{
    T mixmember;
}

struct S
{
    mixin Mix!int;
}
