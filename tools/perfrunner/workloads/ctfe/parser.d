// CTFE workload: the kind of code libraries run at compile time. Formats
// expressions with std.format, parses and evaluates them with a small
// recursive descent parser, and runs a std.algorithm pipeline.
import std.algorithm : filter, map;
import std.array : array;
import std.conv : to;
import std.format : format;
import std.range : iota;

struct Parser
{
    string src;
    size_t pos;

    long expr()
    {
        long value = term();
        while (pos < src.length && (src[pos] == '+' || src[pos] == '-'))
        {
            immutable op = src[pos++];
            immutable rhs = term();
            value = op == '+' ? value + rhs : value - rhs;
        }
        return value;
    }

    long term()
    {
        long value = atom();
        while (pos < src.length && src[pos] == '*')
        {
            pos++;
            value *= atom();
        }
        return value;
    }

    long atom()
    {
        if (src[pos] == '(')
        {
            pos++;
            immutable value = expr();
            pos++;
            return value;
        }
        immutable start = pos;
        while (pos < src.length && src[pos] >= '0' && src[pos] <= '9')
            pos++;
        return src[start .. pos].to!long;
    }
}

long run(int n)
{
    long total;
    foreach (i; 0 .. n)
    {
        auto parser = Parser(format("(%s+%s)*%s-%s", i, i + 1, i % 7, i));
        total += parser.expr();
        total += iota(10).map!(x => x * i).filter!(x => x % 2 == 0).array.length;
    }
    return total;
}

version (Baseline) {} else
enum result = run(300);
