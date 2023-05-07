module dmd.bettererrors;

import dmd.ast_node;
import dmd.console;
import dmd.expression;
import dmd.globals;
import dmd.location;
import dmd.mtype;
import dmd.visitor;
import dmd.root.optional;

/++++ General types ++++/

private alias SinkFuncT = void delegate(scope const(char)[], Optional!Color = Optional!Color.init) nothrow;

private enum bool isInstanceOf(alias S, T) = is(T == S!Args, Args...);
private template isInstanceOf(alias S, alias T)
{
    enum impl(alias T : S!Args, Args...) = true;
    enum impl(alias T) = false;
    enum isInstanceOf = impl!T;
}

/++++ Error configuration ++++/

private:

template ErrorConfig(Options_...)
{
    alias Options = Options_;

    static foreach(option; Options)
    {
        static if(isInstanceOf!(WithParams, option))
        {
            alias Params = option.ParamTypes;
        }
        else static if(isInstanceOf!(WithBasicMessage, option) || isInstanceOf!(WithAdvancedMessage, option))
        {
            static if(option.Level == ErrorVerbosity.normal)
                alias MessageNormal = option;
            else static if(option.Level == ErrorVerbosity.verbose)
                alias MessageVerbose = option;
            else static if(option.Level == ErrorVerbosity.detailed)
                alias MessageDetailed = option;
            else static assert(false, "ErrorVerbosity level is unhandled");
        }
    }

    static if(__traits(compiles, MessageNormal))
    {
        static if(!__traits(compiles, MessageVerbose))
            alias MessageVerbose = MessageNormal;
        static if(!__traits(compiles, MessageDetailed))
            alias MessageDetailed = MessageVerbose;
    } else static assert(false, "A message for ErrorVerbosity.normal must be specified");
}

template WithParams(ParamT_...)
{
    alias ParamTypes = ParamT_;
}

template WithBasicMessage(ErrorVerbosity Level_, Values_...)
{
    enum Level = Level_;
    alias Values = Values_;

    void toSink(Params...)(scope SinkFuncT sink, Params params)
    {
        static foreach(value; Values)
        {
            static if(isInstanceOf!(ParamRef, value))
            {
                formatterToSink(Level, sink, params[value.ParamIndex]);
            }
            else static if(__traits(compiles, typeof(value)))
            {
                formatterToSink(Level, sink, value);
            }
            else static assert(false, "TODO: Message");
        }
    }
}

template ParamRef(size_t ParamIndex_)
{
    enum ParamIndex = ParamIndex_;
}

template WithAdvancedMessage(ErrorVerbosity Level_, alias MessageFunc_)
{
    enum Level = Level_;
    alias MessageFunc = MessageFunc_;

    void toSink(Params...)(scope SinkFuncT sink, Params params) nothrow
    {
        MessageFunc(sink, params);
    }
}

/++++ Type Formatters ++++/

private:

void formatterToSink(ErrorVerbosity level, scope SinkFuncT sink, string value) nothrow
{
    sink(value);
}

void formatterToSink(ErrorVerbosity level, scope SinkFuncT sink, ASTNode node) nothrow
{
    scope visitor = new FormatVisitor(level, sink);

    try node.accept(visitor);
    catch(Exception ex)
        assert(false);
}

extern(C++) class FormatVisitor : Visitor
{
    import core.stdc.string : strlen;

    alias visit = Visitor.visit;
    ErrorVerbosity level;
    SinkFuncT sink;

    extern(D) this(ErrorVerbosity level, scope SinkFuncT sink) nothrow scope
    {
        this.level = level;
        this.sink = sink;
    }

    override void visit(Expression exp)
    {
        scope ptr = exp.toChars();
        sink("`");
        sink(ptr[0..strlen(ptr)], Optional!Color(Color.bright));
        sink("`");
    }

    override void visit(Type type)
    {
        scope ptr = type.toChars();
        sink("`");
        sink(ptr[0..strlen(ptr)], Optional!Color(Color.bright));
        sink("`");
    }
}

/++++ Errors ++++/

private:

mixin template ErrorFuncs(alias Config)
{
    import dmd.errors;

    nothrow static:

    extern(D) void toSink(
        ErrorVerbosity level,
        scope SinkFuncT sink, 
        Config.Params params,
    )
    {
        final switch(level) with(ErrorVerbosity)
        {
            case normal: Config.MessageNormal.toSink(sink, params); break;
            case verbose: Config.MessageVerbose.toSink(sink, params); break;
            case detailed: Config.MessageDetailed.toSink(sink, params); break;
        }
    }

    extern(D) void byLine(
        ErrorVerbosity level,
        scope void delegate(size_t, scope const(char)[], Optional!Color) nothrow sink,
        Config.Params params,
    )
    {
        import dmd.common.outbuffer;

        size_t lineNum;
        scope buffer = OutBuffer(1024);
        Optional!Color lastColor;

        void flushLines()
        {
            size_t index;
            while(index < buffer.length)
            {
                if(buffer[index] == '\n')
                {
                    scope slice = buffer[0..index];
                    sink(lineNum++, slice, lastColor);
                    foreach(i, ch; buffer[index+1..$])
                        buffer.buf[i] = ch;
                    buffer.setsize(buffer.length - (slice.length + 1));
                    index = 0;
                }
                else
                    index++;
            }
            sink(lineNum, buffer[0..$], lastColor);
            buffer.setsize(0);
        }

        toSink(level, (scope line, color)
        {
            if(color != lastColor)
            {
                flushLines();
                lastColor = color;
            }
            buffer.writestring(line);
        }, params);
        flushLines();
    }

    void toStderr(
        const ref Loc loc,
        ErrorVerbosity level,
        Color headerColor,
        scope const(char)* header,
        Config.Params params,
    )
    {
        import core.stdc.stdio : fprintf, stderr, fflush, fputs;
        import core.stdc.string : strlen;
        import dmd.root.rmem : mem;

        const locChars = loc.toChars();
        scope(exit)
        {
            if(*locChars)
                mem.xfree(cast(void*)locChars);
            fflush(stderr);
        }

        char[32] paddingChars;
        size_t headerLen;
        if(header)
        {
            headerLen = strlen(header);
            assert(headerLen <= paddingChars.length-1, "Header is larger than padding chars");

            if(headerLen)
            {
                paddingChars[0..headerLen] = ' ';
                paddingChars[headerLen] = '\0';
            }
        }

        Console con = cast(Console) global.console;
        auto lastLineNum = size_t.max;
        byLine(level, (lineNum, scope line, color)
        {
            if(lineNum != lastLineNum)
            {
                if(lineNum != 0)
                    fputs("\n", stderr);

                if(con)
                    con.setColorBright(true);
                fprintf(stderr, "%s: ", locChars);

                if(con)
                    con.setColor(headerColor);
                if(lineNum == 0)
                    fputs(header, stderr);
                else if(headerLen)
                    fputs(paddingChars.ptr, stderr);

                lastLineNum = lineNum;
            }

            if(con)
            {
                con.resetColor();
                if(color.isPresent())
                {
                    if(color.get() != Color.bright)
                        con.setColor(color.get());
                    else
                        con.setColorBright(true);
                }
            }

            if(line.length)
            {
                assert(line.length <= int.max, "Line slice is too large");
                fprintf(stderr, "%.*s", cast(int)line.length, &line[0]);
            }
        }, params);
        fputs("\n", stderr);
    }

    void error(const ref Loc loc, Config.Params params)
    {
        import dmd.errors : fatal;

        const verbosity = global.params.errorVerbosity;
        global.errors++;
        if (!global.gag)
        {
            toStderr(loc, verbosity, Color.brightRed, "Error: ", params);
            if (global.params.errorLimit && global.errors >= global.params.errorLimit)
                fatal(); // moderate blizzard of cascading messages
        }
        else
        {
            if (global.params.showGaggedErrors)
                toStderr(loc, verbosity, Color.brightRed, "Error: ", params);
            global.gaggedErrors++;
        }
    }
}

public:

extern(C++) struct ErrorCannotImplicitlyCast
{
    mixin ErrorFuncs!(ErrorConfig!(
        WithParams!(Expression, Type, Type),
        WithBasicMessage!(ErrorVerbosity.normal,
            "cannot implicitly convert expression ",
            ParamRef!0,
            " of type ",
            ParamRef!1,
            " to ",
            ParamRef!2
        ),
        WithBasicMessage!(ErrorVerbosity.verbose,
            "cannot implicitly convert expression ",
            ParamRef!0,
            " of type\n  ",
            ParamRef!1,
            "\nto\n  ",
            ParamRef!2,
        )
    ));
}