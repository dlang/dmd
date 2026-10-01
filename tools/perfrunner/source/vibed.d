module vibed;

import std.process : execute;

string[] describeFlags(string dir, string dmd)
{
    auto r = execute(["dub", "describe", "--root=" ~ dir, "--compiler=" ~ dmd,
        "--data=versions,import-paths,string-import-paths"]);
    if (r.status != 0)
        throw new Exception("dub describe failed:\n" ~ r.output);
    return splitFlags(r.output);
}

string[] splitFlags(string output)
{
    string[] flags;
    char[] flag;
    bool quoted, started;

    foreach (c; output)
    {
        if (c == '\'')
            quoted = !quoted;
        else if (!quoted && (c == ' ' || c == '\t' || c == '\n' || c == '\r'))
        {
            if (started)
                flags ~= flag.idup;
            flag.length = 0;
            started = false;
            continue;
        }
        else
            flag ~= c;
        started = true;
    }

    if (started)
        flags ~= flag.idup;
    return flags;
}

unittest
{
    auto sample = "-version=Have_vibe_d -version=EventcoreEpollDriver "
        ~ "'-I/home/me/my dub/packages/vibe-d/0.10.3/vibe-d/source/' "
        ~ "-I/home/me/.dub/packages/eventcore/0.9.39/eventcore/source/\n";

    assert(splitFlags(sample) == [
        "-version=Have_vibe_d",
        "-version=EventcoreEpollDriver",
        "-I/home/me/my dub/packages/vibe-d/0.10.3/vibe-d/source/",
        "-I/home/me/.dub/packages/eventcore/0.9.39/eventcore/source/",
    ]);
}
