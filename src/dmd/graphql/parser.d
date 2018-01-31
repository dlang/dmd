/**
This module parses a graphql _SelectionSet_ (see facebook.github.io/graphql/draft)
 */
module dmd.graphql.parser;

import dmd.graphql.core;

class GraphQLParseException : Exception
{
    this(string msg, string filename, size_t line)
    {
        super(msg, filename, line);
    }
}

/**
Policy must contain the following fields:
---
struct Policy
{
    alias CharType = char;
    enum bool useEofChar;

    // If useEofChar is true, then must have:
    enum char eofChar;

}
---
 */
template graphqlParser(Policy)
{
    alias Char = Policy.CharType;
    static if (Policy.useEofChar)
        enum eofChar = Policy.eofChar;
    else
        enum eofChar = dchar.max;

    /**
    Note: this parses a single graphql "OperationDefinition".
     */
    QuerySelectionSet parseSelectionSet(string str, string filenameForErrors)
    {
        auto parser =  Parser(str.ptr);
        parser.filenameForErrors = filenameForErrors;
        parser.start = str.ptr;
        static if (!Policy.useEofChar)
        {
            parser.limit = str.ptr + str.length;
        }
        parser.readNext();
        return parser.parseSelectionSet();
    }
    /*
    TODO: dmd will probably just support a list of QueryFields
    QueryField[] parseQueryFields(string str, string filenameForErrors)
    {
        ....
    }
    */
    

    struct Parser
    {
        immutable(Char)* nextPtr;
        immutable(Char)* currentPtr = void;
        dchar current = void;
        immutable(Char)* start;
        string filenameForErrors;
    
        static if (!Policy.useEofChar)
        {
            immutable(Char)* limit;
        }

        void readNext()
        {
            currentPtr = nextPtr;
            static if (!Policy.useEofChar)
            {
                if (currentPtr >= limit)
                {
                    current = current.max; // means EOF
                    return;
                }
            }

            // TODO: handle UTF8 here
            current = *currentPtr;
            nextPtr++;
        }
        auto parseError(T...)(immutable(Char)* location, string fmt, T args)
        {
            import std.format : format;
            return new GraphQLParseException(format(fmt, args), filenameForErrors, countLinesTo(location));
        }
        // graphql accepts '\n', '\r\n' or '\r' as line terminators
        private size_t countLinesTo(immutable(Char)* to)
        {
            size_t line = 1;
            auto ptr = start;
            for (; ptr < to; ptr++)
            {
                if (*ptr == '\n')
                {
                    line++;
                }
                else if (*ptr == '\r')
                {
                    ptr++;
                    if (ptr >= to)
                    {
                        static if (Policy.useEofChar)
                        {
                            if (*to != '\n')
                                line++;
                        }
                        else
                        {
                            if (to >= limit || *to != '\n')
                                line++;
                        }
                        break;
                    }
                    line++;
                    if (*ptr != '\n')
                        ptr--;
                }
            }
            return line;
        }

        /**
        Skips whitespace, newline, comments, and commas
        Assumption: current holds the first character to check
        */
        void skipTrivial()
        {
            for (;; readNext())
            {
                if (current == ' '  || current == '\t' ||
                    current == '\n' || current == '\r' ||
                    current == ',')
                    continue;
                if (current == '#')
                    assert(0, "not implemented");
                break;
            }
        }

        QuerySelectionSet parseSelectionSet()
        {
             skipTrivial();
             if (current == '{')
             {
                 readNext();
                 auto set = QuerySelectionSet(parseSelections());
                 assert(current == '}');
                 readNext();
                 return set;
             }
             if (current == eofChar)
                 return QuerySelectionSet();

             throw parseError(currentPtr, "expected selection set but got '%s'", current);
        }
        QuerySelection[] parseSelections()
        {
            QuerySelection[] set = null;
            for (;;)
            {
                // TODO: detect fragment and error in that case
                skipTrivial();
                if (current == '}')
                    return set;

                //
                // Parse "[ Alias ':' ] Name"
                //
                string name = void;
                if (!isNameStart(current))
                    throw parseError(currentPtr, "expected a name but got '%s'", current);
                name = scanName();

                skipTrivial();
                string alias_ = null;
                if (current == ':')
                {
                    alias_ = name;
                    readNext();
                    skipTrivial();
                    if (!isNameStart(current))
                        throw parseError(currentPtr, "expected a name after an alias, but got '%s'", current);
                    name = scanName();
                }

                //
                // Parse optional Arguments
                //
                skipTrivial();
                QueryArgument[] arguments;
                if (current == '(')
                {
                    assert(0, "arguments not implemented");
                }

                //
                // Parse optional Directives
                //
                QueryDirective[] directives;
                for (;;)
                {
                    skipTrivial();
                    if (current != '@')
                    {
                        break;
                    }
                    assert(0, "directive not implemented");
                }

                //
                // Parse optional SelectionSet
                //
                skipTrivial();
                QuerySelectionSet subSelectionSet;
                if (current == '{')
                {
                    assert(0, "sub selection-set not implemented");
                }

                set ~= QuerySelection(QueryField(alias_, name, arguments, directives, subSelectionSet));
            }
        }
        // Assumption: current is pointing to the first char of the name
        //             and it already satisfied isNameStart
        string scanName()
        {
            auto start = currentPtr;
            for (;;)
            {
                readNext();
                if (!isNameChar(current))
                {
                    return start[0 .. currentPtr - start];
                }
            }
        }
    }
}

bool isNameStart(dchar c)
{
    if (c >= 'a') return c <= 'z';
    return (c >= 'A') && (c <= 'Z' || c == '_');
}
bool isNameChar(dchar c)
{
    if (c >= 'a') return c <= 'z';
    if (c >= 'A') return c <= 'Z' || c == '_';
    return c >= '0' && c <= '9';
}

version(unittest)
{
    struct Policy1
    {
        alias CharType = char;
        enum bool useEofChar = false;
    }
    struct Policy2
    {
        alias CharType = char;
        enum bool useEofChar = true;
        enum char eofChar = '\0';
    }
}

unittest
{
    static void test(string str, QuerySelection[] expected, size_t testLine = __LINE__)
    {
        import std.stdio;
        writefln("TEST '%s'", str);
        import std.conv : to;
        string filename = "line-" ~ testLine.to!string;
        // test using Policy1
        {
            auto actual = graphqlParser!Policy1.parseSelectionSet(str, filename);
            assert(actual.selections == expected);            
        }
        // test using Policy2
        {
            auto strWithNull = str ~ "\0";
            auto actual = graphqlParser!Policy2.parseSelectionSet(strWithNull[0 .. $-1], filename);
            assert(actual.selections == expected);            
        }
    }
    static void testBad(size_t line, string str, size_t testLine = __LINE__)
    {
        import std.stdio;
        writefln("TEST-BAD '%s'", str);
        import std.conv : to;
        string filename = "line-" ~ testLine.to!string;

        // test using Policy1
        try { graphqlParser!Policy1.parseSelectionSet(str, filename); assert(0); }
        catch(GraphQLParseException e)
        { assert(e.line == line); }

        // test using Policy2
        try { graphqlParser!Policy1.parseSelectionSet(str ~ "\0", filename); assert(0); }
        catch(GraphQLParseException e)
        { assert(e.line == line); }
    }
    static QuerySelection field(string alias_, string name)
    {
        return QuerySelection(QueryField(alias_, name));
    }

    test(null, null);
    test("", null);
    test(",  \n\r  ", null);
    test("{,\n,\r}", null);

    testBad(1, "{");
    testBad(2, "\r{");
    testBad(1, "a");
    testBad(3, "{\n\ta\n");

    test("{a}", [field(null, "a")]);
    test("{a:b}", [field("a", "b")]);
}

// test line number accuracy
//
// graphql accepts '\n', '\r\n' or '\r' as line terminators
unittest
{
    static void test(size_t line, size_t offset, string str)
    {
        // test using Policy1
        {
            auto parser = graphqlParser!Policy1.Parser();
            parser.start = str.ptr;
            parser.limit = str.ptr + str.length;
            assert(line == parser.countLinesTo(str.ptr + offset));
        }
        // test using Policy2
        {
            auto strWithNull = str ~ "\0";
            auto parser = graphqlParser!Policy2.Parser();
            parser.start = str.ptr;
            assert(line == parser.countLinesTo(str.ptr + offset));
        }
    }
    test(1, 0, null);
    test(1, 0, "");
    test(1, 2, "  ");

    test(2, 1, "\n");
    test(2, 1, "\r");
    test(2, 2, "\r\n");
    test(1, 1, "\r\n");
    
    test(3, 2, "\n\n");
    test(2, 1, "\n\n");
    test(3, 2, "\n\r");
    test(2, 1, "\n\r");
    test(3, 3, "\n\r\n");
    test(2, 2, "\n\r\n");

    test(3, 2, "\r\r");
    test(2, 1, "\r\r");
    test(3, 3, "\r\r\n");
    test(2, 2, "\r\r\n");
    test(2, 1, "\r\r\n");

    test(3, 3, "\r\n\n");
    test(2, 2, "\r\n\n");
    test(1, 1, "\r\n\n");
    test(3, 3, "\r\n\r");
    test(2, 2, "\r\n\r");
    test(1, 1, "\r\n\r");
    test(3, 4, "\r\n\r\n");
    test(2, 3, "\r\n\r\n");
    test(2, 2, "\r\n\r\n");
    test(1, 1, "\r\n\r\n");
}