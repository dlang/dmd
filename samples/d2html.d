/*
 * Copyright (c) 2001
 * Pavel "EvilOne" Minayev
 *
 * Permission to use, copy, modify, distribute and sell this software
 * and its documentation for any purpose is hereby granted without fee,
 * provided that the above copyright notice appear in all copies and
 * that both that copyright notice and this permission notice appear
 * in supporting documentation.  Author makes no representations about
 * the suitability of this software for any purpose. It is provided
 * "as is" without express or implied warranty.
 */

import std.c.stdio;
import std.string;
import std.stream;      // don't forget to link with stream.obj!

// colors for syntax highlighting, default values are
// my preferences in Microsoft Visual Studio editor
class Colors
{
        static char[] keyword = "0000FF";
        static char[] number = "008000";
        static char[] string = "000080";
        static char[] comment = "808080";
}

const int tabsize = 4;  // number of spaces in tab
const char[24] symbols = "()[]{}.,;:=<>+-*/%&|^!~?";
char[][] keywords;

// true if c is whitespace, false otherwise
bit isspace(char c)
{
        return find(whitespace, c) >= 0;
}

// true if c is a letter or an underscore, false otherwise
bit isalpha(char c)
{
        // underscore doesn't differ from letters in D anyhow...
        return c == '_' || find(letters, c) >= 0;
}

// true if c is a decimal digit, false otherwise
bit isdigit(char c)
{
        return find(digits, c) >= 0;
}

// true if c is a hexadecimal digit, false otherwise
bit ishexdigit(char c)
{
        return find(hexdigits, c) >= 0;
}

// true if c is an octal digit, false otherwise
bit isoctdigit(char c)
{
        return find(octdigits, c) >= 0;
}

// true if c is legal D symbol other than above, false otherwise
bit issymbol(char c)
{
        return find(symbols, c) >= 0;
}

// true if token is a D keyword, false otherwise
bit iskeyword(char[] token)
{
        for (int i = 0; i < keywords.length; i++)
                if (!cmp(keywords[i], token))
                        return true;
        return false;
}

int main(char[][] args)
{
        // need help?
        if (args.length < 2 || args.length > 3)
        {
                printf("D to HTML converter\n"
                        "Usage: D2HTML <program>.d [<file>.htm]\n");
                return 0;
        }
        // auto-name output file
        if (args.length == 2)
                args ~= args[1] ~ ".htm";
        // load keywords
        File kwd = new File("d2html.kwd");
        while (!kwd.eof())
                keywords ~= kwd.readLine();
        kwd.close();
        // open input and output files
        File src = new File(args[1]), dst = new File;
        dst.create(args[2]);
        // write HTML header
        dst.writeLine("<html><head><title>" ~ args[1] ~ "</title></head>");
        dst.writeLine("<body color='#000000' bgcolor='#FFFFFF'><pre><code>");
        // the main part is wrapped into try..catch block because
        // when end of file is reached, an exception is raised;
        // so we can omit any checks for EOF inside this block...
        try
        {
                int linestart = 0;      // for tabs
                char c;
                src.read(c);
                while (true)
                {
                        if (isspace(c))         // whitespace
                        {
                                do
                                {
                                        if (c == 9)
                                        {
                                                // expand tabs to spaces
                                                int spaces = tabsize -
                                                        (src.position() - linestart) % tabsize;
                                                for (int i = 0; i < spaces; i++)
                                                        dst.writeString(" ");
                                                linestart = src.position() - tabsize + 1;
                                        }
                                        else
                                        {
                                                // reset line start on newline
                                                if (c == 10 || c == 13)
                                                        linestart = src.position() + 1;
                                                dst.write(c);
                                        }
                                        src.read(c);
                                } while (isspace(c));
                        }
                        else if (isalpha(c))    // keyword or identifier
                        {
                                char[] token;
                                do
                                {
                                        token ~= c;
                                        src.read(c);
                                } while (isalpha(c) || isdigit(c));
                                if (iskeyword(token))   // keyword
                                        dst.writeString("<font color='#" ~ Colors.keyword ~
                                                "'>" ~ token ~ "</font>");
                                else    // simple identifier
                                        dst.writeString(token);
                        }
                        else if (c == '0')      // binary, octal or hexadecimal number
                        {
                                dst.writeString("<font color='#" ~ Colors.number ~ "008000'>");
                                dst.write(c);
                                src.read(c);
                                if (c == 'X' || c == 'x')       // hexadecimal
                                {
                                        dst.write(c);
                                        src.read(c);
                                        while (ishexdigit(c))
                                                dst.write(c);
                                        // TODO: add support for hexadecimal floats
                                }
                                else if (c == 'B' || c == 'b')  // binary
                                {
                                        dst.write(c);
                                        src.read(c);
                                        while (c == '0' || c == '1')
                                                dst.write(c);
                                }
                                else    // octal
                                {
                                        do
                                        {
                                                dst.write(c);
                                                src.read(c);
                                        } while (isoctdigit(c));
                                }
                                dst.writeString("</font>");
                        }
                        else if (isdigit(c))    // decimal number
                        {
                                dst.writeString("<font color='#" ~ Colors.number ~ "'>");
                                // integral part
                                do
                                {
                                        dst.write(c);
                                        src.read(c);
                                } while (isdigit(c));
                                // fractional part
                                if (c == '.')
                                {
                                        dst.write(c);
                                        src.read(c);
                                        while (isdigit(c))
                                        {
                                                dst.write(c);
                                                src.read(c);
                                        }
                                }
                                // scientific notation
                                if (c == 'E' || c == 'e')
                                {
                                        dst.write(c);
                                        src.read(c);
                                        if (c == '+' || c == '-')
                                        {
                                                dst.write(c);
                                                src.read(c);
                                        }
                                        while (isdigit(c))
                                        {
                                                dst.write(c);
                                                src.read(c);
                                        }
                                }
                                // suffices
                                while (c == 'U' || c == 'u' || c == 'L' ||
                                        c == 'l' || c == 'F' || c == 'f')
                                {
                                        dst.write(c);
                                        src.read(c);
                                }
                                dst.writeString("</font>");
                        }
                        else if (c == '\'')     // string without escape sequences
                        {
                                dst.writeString("<font color='#" ~ Colors.string ~ "'>");
                                do
                                {
                                        if (c == '<')   // special symbol in HTML
                                                dst.writeString("&lt;");
                                        else
                                                dst.write(c);
                                        src.read(c);
                                } while (c != '\'');
                                dst.write(c);
                                src.read(c);
                                dst.writeString("</font>");
                        }
                        else if (c == 34)       // string with escape sequences
                        {
                                dst.writeString("<font color='#" ~ Colors.string ~ "'>");
                                char prev;      // used to handle \" properly
                                do
                                {
                                        if (c == '<')   // special symbol in HTML
                                                dst.writeString("&lt;");
                                        else
                                                dst.write(c);
                                        prev = c;
                                        src.read(c);
                                } while (!(c == 34 && prev != '\\'));   // handle \"
                                dst.write(c);
                                src.read(c);
                                dst.writeString("</font>");
                        }
                        else if (issymbol(c))   // either operator or comment
                        {
                                if (c == '<')   // special symbol in HTML
                                {
                                        dst.writeString("&lt;");
                                        src.read(c);
                                }
                                else if (c == '/')      // could be a comment...
                                {
                                        src.read(c);
                                        if (c == '/')   // single-line one
                                        {
                                                dst.writeString("<font color='#" ~ Colors.comment ~ "'>/");
                                                while (c != 10)
                                                {
                                                        if (c == '<')   // special symbol in HTML
                                                                dst.writeString("&lt;");
                                                        else if (c == 9)
                                                        {
                                                                // expand tabs
                                                                int spaces2 = tabsize -
                                                                        (src.position() - linestart) % tabsize;
                                                                for (int i2 = 0; i2 < spaces2; i2++)
                                                                        dst.writeString(" ");
                                                                linestart = src.position() - tabsize + 1;
                                                        }
                                                        else
                                                                dst.write(c);
                                                        src.read(c);
                                                }
                                                dst.writeString("</font>");
                                        }
                                        else if (c == '*')      // multi-line one
                                        {
                                                dst.writeString("<font color='#" ~ Colors.comment ~ "'>/");
                                                char prev2;
                                                do
                                                {
                                                        if (c == '<')   // special symbol in HTML
                                                                dst.writeString("&lt;");
                                                        else if (c == 9)
                                                        {
                                                                // expand tabs
                                                                int spaces3 = tabsize -
                                                                        (src.position() - linestart) % tabsize;
                                                                for (int i3 = 0; i3 < spaces3; i3++)
                                                                        dst.writeString(" ");
                                                                linestart = src.position() - tabsize + 1;
                                                        }
                                                        else
                                                        {
                                                                // reset line start on newline
                                                                if (c == 10 || c == 13)
                                                                        linestart = src.position() + 1;
                                                                dst.write(c);
                                                        }
                                                        prev2 = c;
                                                        src.read(c);
                                                } while (!(c == '/' && prev2 == '*'));
                                                dst.write(c);
                                                dst.writeString("</font>");
                                                src.read(c);
                                        }
                                        else    // just an operator
                                                dst.write(cast(char) '/');
                                }
                                else    // just an operator
                                {
                                        dst.write(c);
                                        src.read(c);
                                }
                        }
                        else
                                // whatever it is, it's not a valid D token
                                throw new Error("unrecognized token");
                }
        }
        // if end of file is reached and we try to read something
        // with typed read(), a ReadError is thrown; in our case,
        // this means that job is successfully done
        catch (ReadError e)
        {
                // write HTML footer
                dst.writeLine("</code></pre></body></html>");
        }
        return 0;
}

