
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * https://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/compiler/src/dmd/timetrace.h
 */

#pragma once

#include "dmd/globals.h"

class Expression;
class OutBuffer;

enum class TimeTraceEventType
{
    generic,
    parseGeneral,
    parse,
    semaGeneral,
    sema1Import,
    sema1Module,
    sema2,
    sema3,
    ctfe,
    ctfeCall,
    codegenGlobal,
    codegenModule,
    codegenFunction,
    link
};

namespace dmd
{
    void initializeTimeTrace(unsigned timeGranularityUs, const char *processName);
    void deinitializeTimeTrace();
    bool timeTraceProfilerEnabled();
    void writeTimeTraceProfile(OutBuffer *buf);

    void timeTraceBeginEvent(const char *name_ptr, const char *detail_ptr, Loc loc);
    void timeTraceBeginEvent(TimeTraceEventType eventType);

    void timeTraceEndEvent(TimeTraceEventType eventType);
    void timeTraceEndEvent(TimeTraceEventType eventType, Expression *e);


    /// RAII helper class to call the begin and end functions of the time trace
    /// profiler.  When the object is constructed, it begins the event; and when
    /// it is destroyed, it stops it.
    /// The strings pointed to are copied (pointers are not stored).
    struct TimeTraceScope
    {
        TimeTraceScope() = delete;
        TimeTraceScope(const TimeTraceScope &) = delete;
        TimeTraceScope &operator=(const TimeTraceScope &) = delete;
        TimeTraceScope(TimeTraceScope &&) = delete;
        TimeTraceScope &operator=(TimeTraceScope &&) = delete;

        TimeTraceScope(const char *name, const char *detail = nullptr, Loc loc = Loc())
            : TimeTraceScope(TimeTraceEventType::generic, name, detail, loc)
        {}
        TimeTraceScope(TimeTraceEventType type, const char *name = nullptr, const char *detail = nullptr, Loc loc = Loc())
            : type(type)
        {
            if (timeTraceProfilerEnabled())
                timeTraceBeginEvent(name, detail, loc);
        }

        ~TimeTraceScope()
        {
            if (timeTraceProfilerEnabled())
                timeTraceEndEvent(type);
        }

    private:
        TimeTraceEventType type = TimeTraceEventType::generic;
    };
}
