#pragma once

#include "expression.h"
#include "mtype.h"

struct Loc;

enum ErrorVerbosity
{
    normal,
    verbose,
    detailed,
};

struct ErrorCannotImplicitlyCast
{
    static void toStderr(const Loc& loc, ErrorVerbosity level, const char* header, Expression* p1, Type* p2, Type* p3);
    static void error(const Loc& loc, Expression* p1, Type* p2, Type* p3);
};