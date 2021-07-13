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

import core.stdc.stdio;

import std.conv;
import std.string;
import std.stdio;
import std.ascii;
import std.file;

// colors for syntax highlighting, default values are
// my preferences in Microsoft Visual Studio editor
enum Colors
{
    keyword = "0000FF",
    number  = "008000",
    astring = "000080",
    comment = "808080"
}

enum tabsize = 4;  // number of spaces in tab
bool[string] keywords;


void main(string[] args)
{
    // need help?
    if (args.length < 2 || args.length > 3)
    {
        printf("D to HTML converter\n" ~
               "Usage: D2HTML <program>.d [<file>.htm]\n");
        return;
    }

    // auto-name output file
    if (args.length == 2)
        args ~= args[1] ~ ".htm";

    // load keywords
    assert("d2html.kwd".exists, "file d2html.kwd does not exist");
    auto kwd = File("d2html.kwd");
    foreach (word; kwd.byLine())
        keywords[word.idup] = true;
    kwd.close();

    // open input and output files
    auto src = File(args[1]);
    auto dst = File(args[2], "w");

    // write HTML header
    dst.writeln("<html><head><title>" ~ args[1] ~ "</title></head>");
    dst.writeln("<body color='#000000' bgcolor='#FFFFFF'><pre><code>");

    // the main part is wrapped into try..catch block because
    // when end of file is reached, an exception is raised;
    // so we can omit any checks for EOF inside this block...
    try
    {
        static char readc(ref File src)
        {
            while (true)
            {
                if (src.eof())
                    throw new Exception("");
                char c;
                src.readf("%c", &c);
                if (c != '\r' && c != 0xFF)
                    return c;
            }
        }

        ulong linestart = 0;             // for tabs
        char c;

        c = readc(src);

        while (true)
        {
            if (isWhite(c))                     // whitespace
            {
                do
                {
                    if (c == 9)
                    {
                        // expand tabs to spaces
                        immutable spaces = tabsize -
                                     (src.tell() - linestart) % tabsize;

                        for (int i = 0; i < spaces; i++)
                            dst.write(" ");

                        linestart = src.tell() - tabsize + 1;
                    }
                    else
                    {
                        // reset line start on newline
                        if (c == 10 || c == 13)
                            linestart = src.tell() + 1;

                        dst.write(c);
                    }

                    c = readc(src);
                } while (isWhite(c));
            }
            else if (isAlpha(c))                // keyword or identifier
            {
                string token;

                do
                {
                    token ~= c;
                    c = readc(src);
                } while (isAlpha(c) || isDigit(c));

                if (token in keywords)                   // keyword
                    dst.write("<font color='#" ~ Colors.keyword ~
                                    "'>" ~ token ~ "</font>");
                else                    // simple identifier
                    dst.write(token);
            }
            else if (c == '0')                  // binary, octal or hexadecimal number
            {
                dst.write("<font color='#" ~ Colors.number ~ "008000'>");
                dst.write(c);
                c = readc(src);

                if (c == 'X' || c == 'x')                       // hexadecimal
                {
                    dst.write(c);
                    c = readc(src);

                    while (isHexDigit(c)) {
                        dst.write(c);
                        c = readc(src);
                    }

                    // TODO: add support for hexadecimal floats
                }
                else if (c == 'B' || c == 'b')                  // binary
                {
                    dst.write(c);
                    c = readc(src);

                    while (c == '0' || c == '1') {
                        dst.write(c);
                        c = readc(src);
                    }
                }
                else                    // octal
                {
                    do
                    {
                        dst.write(c);
                        c = readc(src);
                    } while (isOctalDigit(c));
                }

                dst.write("</font>");
            }
            else if (c == '#')                // hash
            {
                dst.write(c);
                c = readc(src);
            }
            else if (c == '\\')                // backward slash
            {
                dst.write(c);
                c = readc(src);
            }
            else if (isDigit(c))                // decimal number
            {
                dst.write("<font color='#" ~ Colors.number ~ "'>");

                // integral part
                do
                {
                    dst.write(c);
                    c = readc(src);
                } while (isDigit(c));

                // fractional part
                if (c == '.')
                {
                    dst.write(c);
                    c = readc(src);

                    while (isDigit(c))
                    {
                        dst.write(c);
                        c = readc(src);
                    }
                }

                // scientific notation
                if (c == 'E' || c == 'e')
                {
                    dst.write(c);
                    c = readc(src);

                    if (c == '+' || c == '-')
                    {
                        dst.write(c);
                        c = readc(src);
                    }

                    while (isDigit(c))
                    {
                        dst.write(c);
                        c = readc(src);
                    }
                }

                // suffices
                while (c == 'U' || c == 'u' || c == 'L' ||
                       c == 'l' || c == 'F' || c == 'f')
                {
                    dst.write(c);
                    c = readc(src);
                }

                dst.write("</font>");
            }
            else if (c == '\'')                 // string without escape sequences
            {
                dst.write("<font color='#" ~ Colors.astring ~ "'>");

                do
                {
                    if (c == '<')                       // special symbol in HTML
                        dst.write("&lt;");
                    else
                        dst.write(c);

                    c = readc(src);
                } while (c != '\'');
                dst.write(c);
                c = readc(src);
                dst.write("</font>");
            }
            else if (c == 34)                   // string with escape sequences
            {
                dst.write("<font color='#" ~ Colors.astring ~ "'>");
                char prev;                      // used to handle \" properly

                do
                {
                    if (c == '<')                       // special symbol in HTML
                        dst.write("&lt;");
                    else
                        dst.write(c);

                    prev = c;
                    c = readc(src);
                } while (!(c == 34 && prev != '\\'));                   // handle \"
                dst.write(c);
                c = readc(src);
                dst.write("</font>");
            }
            else if (isPunctuation(c))          // either operator or comment
            {
                if (c == '<')                   // special symbol in HTML
                {
                    dst.write("&lt;");
                    c = readc(src);
                }
                else if (c == '/')                      // could be a comment...
                {
                    c = readc(src);

                    if (c == '/')                       // single-line one
                    {
                        dst.write("<font color='#" ~ Colors.comment ~ "'>/");

                        while (c != 10)
                        {
                            if (c == '<')                               // special symbol in HTML
                                dst.write("&lt;");
                            else if (c == 9)
                            {
                                // expand tabs
                                immutable spaces2 = tabsize -
                                              (src.tell() - linestart) % tabsize;

                                for (int i2 = 0; i2 < spaces2; i2++)
                                    dst.write(" ");

                                linestart = src.tell() - tabsize + 1;
                            }
                            else
                                dst.write(c);

                            c = readc(src);
                        }

                        dst.write("</font>");
                    }
                    else if (c == '*')                          // multi-line one
                    {
                        dst.write("<font color='#" ~ Colors.comment ~ "'>/");
                        char prev2;

                        do
                        {
                            if (c == '<')                               // special symbol in HTML
                                dst.write("&lt;");
                            else if (c == 9)
                            {
                                // expand tabs
                                immutable spaces3 = tabsize -
                                              (src.tell() - linestart) % tabsize;

                                for (int i3 = 0; i3 < spaces3; i3++)
                                    dst.write(" ");

                                linestart = src.tell() - tabsize + 1;
                            }
                            else
                            {
                                // reset line start on newline
                                if (c == 10 || c == 13)
                                    linestart = src.tell() + 1;

                                dst.write(c);
                            }

                            prev2 = c;
                            c = readc(src);
                        } while (!(c == '/' && prev2 == '*'));
                        dst.write(c);
                        dst.write("</font>");
                        c = readc(src);
                    }
                    else                        // just an operator
                        dst.write(cast(char) '/');
                }
                else                    // just an operator
                {
                    dst.write(c);
                    c = readc(src);
                }
            }
            else
            {
                // whatever it is, it's not a valid D token
                throw new Error("unrecognized token " ~ c);
                //~ break;
            }
        }
    }

    // if end of file is reached and we try to read something
    // with typed read(), a ReadError is thrown; in our case,
    // this means that job is successfully done
    catch (Exception e)
    {
        // write HTML footer
        dst.writeln("</code></pre></body></html>");
    }

    return;
}
