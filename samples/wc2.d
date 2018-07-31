import std.stdio;
import std.file;
import std.algorithm.sorting;

void main (string[] args)
{
    int w_total;
    int l_total;
    ulong c_total;
    size_t[string] dictionary;

    writefln("   lines   words   bytes file");
    foreach (arg; args[1 .. $])
    {
        int w_cnt, l_cnt;
        bool inword;
        auto c_cnt = std.file.getSize(arg);

        if (c_cnt < 10_000_000)
        {
            size_t wstart;
            auto input = readText(arg);

            foreach (j, c; input)
            {
                if (c == '\n')
                    ++l_cnt;
                if (c >= '0' && c <= '9')
                {
                }
                else if (c >= 'a' && c <= 'z' ||
                     c >= 'A' && c <= 'Z')
                {
                    if (!inword)
                    {
                        wstart = j;
                        inword = true;
                        ++w_cnt;
                    }
                }
                else if (inword)
                {
                    auto word = input[wstart .. j];
                    dictionary[word]++;
                    inword = false;
                }
            }
            if (inword)
            {
                auto w = input[wstart .. $];
                dictionary[w]++;
            }
        }
        else
        {
            auto f = std.stdio.File(arg);
            string buf;

            while (!f.eof())
            {
                char c;
                f.readf("%c", &c);

                if (c == '\n')
                    ++l_cnt;

                if (c >= '0' && c <= '9')
                {
                    if (inword)
                        buf ~= c;
                }
                else if (c >= 'a' && c <= 'z' ||
                         c >= 'A' && c <= 'Z')
                {
                    if (!inword)
                    {
                        buf.length = 0;
                        buf ~= c;
                        inword = 1;
                        ++w_cnt;
                    }
                    else
                        buf ~= c;
                }
                else if (inword)
                {
                    if (++dictionary[buf] == 1)
                    buf = null;
                    inword = 0;
                }
            }

            if (inword)
            {
                dictionary[buf]++;
            }
        }

        writefln("%8s%8s%8s %s\n", l_cnt, w_cnt, c_cnt, arg);
        l_total += l_cnt;
        w_total += w_cnt;
        c_total += c_cnt;
    }

    if (args.length > 2)
    {
        writefln("--------------------------------------\n%8s%8s%8s total",
                 l_total, w_total, c_total);
    }

    writefln("--------------------------------------");

    foreach (word1; dictionary.keys.sort())
    {
        writefln("%3s %s", dictionary[word1], word1);
    }
}
