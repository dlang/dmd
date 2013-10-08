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

import std.conv;
import std.string;
import std.stream;    //   don't forget to link with stream.obj!
import std.ascii;

// colors for syntax highlighting, default values are
// my preferences in Microsoft Visual Studio editor
class Colors
{
    static string keyword = "0000FF";
    static string number  = "008000";
    static string astring = "000080";
    static string comment = "808080";
}

const int tabsize = 4;  // number of spaces in tab
const char[24] symbols = "()[]{}.,;:=<>+-*/%&|^!~?";
string[] keywords;

// true if c is whitespace, false otherwise
byte isspace(char c)
{
    return indexOf(whitespace, c) >= 0;
}

// true if c is a letter or an underscore, false otherwise
byte isalpha(char c)
{
    // underscore doesn't differ from letters in D anyhow...
    return c == '_' || indexOf(letters, c) >= 0;
}

// true if c is a decimal digit, false otherwise
byte isdigit(char c)
{
    return indexOf(digits, c) >= 0;
}

// true if c is a hexadecimal digit, false otherwise
byte ishexdigit(char c)
{
    return indexOf(hexDigits, c) >= 0;
}

// true if c is an octal digit, false otherwise
byte isoctdigit(char c)
{
    return indexOf(octalDigits, c) >= 0;
}

// true if c is legal D symbol other than above, false otherwise
byte issymbol(char c)
{
    return indexOf(symbols, c) >= 0;
}

// true if token is a D keyword, false otherwise
byte iskeyword(string token)
{
    foreach (index, key; keywords)
    {
        if (!cmp(keywords[index], token))
            return true;
    }

    return false;
}

int main(string[] args)
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
        keywords ~= to!string(kwd.readLine());

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
        ulong linestart = 0;             // for tabs
        char c;
        src.read(c);

        while (true)
        {
            if (isspace(c))                     // whitespace
            {
                do
                {
                    if (c == 9)
                    {
                        // expand tabs to spaces
                        auto spaces = tabsize -
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
            else if (isalpha(c))                // keyword or identifier
            {
                string token;

                do
                {
                    token ~= c;
                    src.read(c);
                } while (isalpha(c) || isdigit(c));

                if (iskeyword(token))                   // keyword
                    dst.writeString("<font color='#" ~ Colors.keyword ~
                                    "'>" ~ token ~ "</font>");
                else                    // simple identifier
                    dst.writeString(token);
            }
            else if (c == '0')                  // binary, octal or hexadecimal number
            {
                dst.writeString("<font color='#" ~ Colors.number ~ "008000'>");
                dst.write(c);
                src.read(c);

                if (c == 'X' || c == 'x')                       // hexadecimal
                {
                    dst.write(c);
                    src.read(c);

                    while (ishexdigit(c)) {
                        dst.write(c);
                        src.read(c);
		    }

                    // TODO: add support for hexadecimal floats
                }
                else if (c == 'B' || c == 'b')                  // binary
                {
                    dst.write(c);
                    src.read(c);

                    while (c == '0' || c == '1') {
                        dst.write(c);
                        src.read(c);
		    }
                }
                else                    // octal
                {
                    do
                    {
                        dst.write(c);
                        src.read(c);
                    } while (isoctdigit(c));
                }

                dst.writeString("</font>");
            }
            else if (c == '#')                // hash
            {
                dst.write(c);
                src.read(c);
            }
            else if (c == '\\')                // backward slash
            {
                dst.write(c);
                src.read(c);
            }
            else if (isdigit(c))                // decimal number
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
            else if (c == '\'')                 // string without escape sequences
            {
                dst.writeString("<font color='#" ~ Colors.astring ~ "'>");

                do
                {
                    if (c == '<')                       // special symbol in HTML
                        dst.writeString("&lt;");
                    else
                        dst.write(c);

                    src.read(c);
                } while (c != '\'');
                dst.write(c);
                src.read(c);
                dst.writeString("</font>");
            }
            else if (c == 34)                   // string with escape sequences
            {
                dst.writeString("<font color='#" ~ Colors.astring ~ "'>");
                char prev;                      // used to handle \" properly

                do
                {
                    if (c == '<')                       // special symbol in HTML
                        dst.writeString("&lt;");
                    else
                        dst.write(c);

                    prev = c;
                    src.read(c);
                } while (!(c == 34 && prev != '\\'));                   // handle \"
                dst.write(c);
                src.read(c);
                dst.writeString("</font>");
            }
            else if (issymbol(c))               // either operator or comment
            {
                if (c == '<')                   // special symbol in HTML
                {
                    dst.writeString("&lt;");
                    src.read(c);
                }
                else if (c == '/')                      // could be a comment...
                {
                    src.read(c);

                    if (c == '/')                       // single-line one
                    {
                        dst.writeString("<font color='#" ~ Colors.comment ~ "'>/");

                        while (c != 10)
                        {
                            if (c == '<')                               // special symbol in HTML
                                dst.writeString("&lt;");
                            else if (c == 9)
                            {
                                // expand tabs
                                auto spaces2 = tabsize -
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
                    else if (c == '*')                          // multi-line one
                    {
                        dst.writeString("<font color='#" ~ Colors.comment ~ "'>/");
                        char prev2;

                        do
                        {
                            if (c == '<')                               // special symbol in HTML
                                dst.writeString("&lt;");
                            else if (c == 9)
                            {
                                // expand tabs
                                auto spaces3 = tabsize -
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
                    else                        // just an operator
                        dst.write(cast(char) '/');
                }
                else                    // just an operator
                {
                    dst.write(c);
                    src.read(c);
                }
            }
            else
                // whatever it is, it's not a valid D token
                throw new Error("unrecognized token " ~ c);
                //~ break;
        }
    }

    // if end of file is reached and we try to read something
    // with typed read(), a ReadError is thrown; in our case,
    // this means that job is successfully done
    catch (Exception e)
    {
        // write HTML footer
        dst.writeLine("</code></pre></body></html>");
    }
    return 0;
}
