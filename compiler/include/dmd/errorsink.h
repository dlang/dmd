
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * https://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/errorsink.h
 */

#pragma once

#include "root/dsystem.h"

struct Loc;

// Constants used to discriminate kinds of error messages.
enum class ErrorKind
{
    warning = 0,
    deprecation = 1,
    error = 2,
    message = 3,
};

class ErrorSink
{
public:
    virtual void verror(Loc loc, const char *format, va_list ap) = 0;
    virtual void verrorSupplemental(Loc loc, const char *format, va_list ap) = 0;
    virtual void vwarning(Loc loc, const char *format, va_list ap) = 0;
    virtual void vwarningSupplemental(Loc loc, const char *format, va_list ap) = 0;
    virtual void vmessage(Loc loc, const char *format, va_list ap) = 0;
    virtual void vdeprecation(Loc loc, const char *format, va_list ap) = 0;
    virtual void vdeprecationSupplemental(Loc loc, const char *format, va_list ap) = 0;

    virtual void error(Loc loc, const char *format, ...);
    virtual void errorSupplemental(Loc loc, const char *format, ...);
    virtual void warning(Loc loc, const char *format, ...);
    virtual void warningSupplemental(Loc loc, const char *format, ...);
    virtual void message(Loc loc, const char *format, ...);
    virtual void deprecation(Loc loc, const char *format, ...);
    virtual void deprecationSupplemental(Loc loc, const char *format, ...);
    virtual void plugSink();
};

class ErrorSinkNull : public ErrorSink
{
public:
    void verror(Loc loc, const char *format, va_list ap) override;
    void verrorSupplemental(Loc loc, const char *format, va_list ap) override;
    void vwarning(Loc loc, const char *format, va_list ap) override;
    void vwarningSupplemental(Loc loc, const char *format, va_list ap) override;
    void vmessage(Loc loc, const char *format, va_list ap) override;
    void vdeprecation(Loc loc, const char *format, va_list ap) override;
    void vdeprecationSupplemental(Loc loc, const char *format, va_list ap) override;
};

class ErrorSinkLatch : public ErrorSinkNull
{
public:
    bool sawErrors;

    void verror(Loc loc, const char *format, va_list ap) override;
};

class ErrorSinkStderr : public ErrorSink
{
public:
    void verror(Loc loc, const char *format, va_list ap) override;
    void verrorSupplemental(Loc loc, const char *format, va_list ap) override;
    void vwarning(Loc loc, const char *format, va_list ap) override;
    void vwarningSupplemental(Loc loc, const char *format, va_list ap) override;
    void vdeprecation(Loc loc, const char *format, va_list ap) override;
    void vmessage(Loc loc, const char *format, va_list ap) override;
    void vdeprecationSupplemental(Loc loc, const char *format, va_list ap) override;
};
