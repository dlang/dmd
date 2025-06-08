// https://github.com/dlang/dmd/issues/21435

import core.stdc.stdlib, core.stdc.string;

struct Strings
{
    size_t length;
    alias T = const(char)*;
private:
    T[] data;

public:
    ref Strings push(T ptr) return
    {
        reserve(1);
        data[length++] = ptr;
        return this;
    }

    void reserve(size_t nentries)
    {
        void enlarge(size_t nentries)
        {
            const allocdim = length + nentries;
            auto p = cast(T*)malloc(allocdim * T.sizeof);
            data = p[0..allocdim];
        }

        if (data.length - length < nentries)  // false means hot path
            enlarge(nentries);
    }
}

void check_align()
{
    pragma(inline, false);
    int x;
    (cast(size_t)&x & 3) == 0 || assert(false);
}

void getenv_setargv(const(char)* envvalue, Strings* args)
{
    if (!envvalue)
        return;

    char* env = strdup(envvalue); // create our own writable copy

    while (1)
    {
        switch (*env)
        {
            case 0:
                check_align();
                return;

            default:
            {
                args.push(env);
                auto p = env;
                while (1)
                {
                    auto c = *env++;
                    switch (c)
                    {
                        case 0:
                            env--;
                            *p = 0;
                            break;

                        default:
                            *p++ = c;
                            continue; // increments RSP here!
                    }
                    break;
                }
                break;
            }
        }
    }
}

void main()
{
	Strings str;
	getenv_setargv("val", &str); // good enough if it doesn't crash
	str.length == 1 || assert(false);
}
