/* REQUIRED_ARGS: -preview=dip1000 -preview=in
 */

@safe:

import std.traits: ParameterStorageClassTuple, ParameterStorageClass, Parameters;

void fun(in int* inParam);
alias storages = ParameterStorageClassTuple!fun;
alias storage = storages[0];

static assert(is(Parameters!fun[0] == const int*));
static assert(storage & ParameterStorageClass.scope_);
