/**
A small library to help write D shell-like test scripts.
*/
module dshell_prebuilt;

public import core.stdc.stdlib : exit;

public import core.time;
public import core.thread;
public import std.meta;
public import std.exception;
public import std.array;
public import std.string;
public import std.format;
public import std.path;
public import std.file;
public import std.regex;
public import std.stdio;
public import std.process;

/**
Emulates bash environment variables. Variables set here will be availble for BASH-like expansion.
*/
struct Vars
{
    private static __gshared string[string] map;
    static void set(string name, string value)
    in { assert(value !is null); } do
    {
        const expanded = shellExpand(value);
        assert(expanded !is null, "codebug");
        map[name] = expanded;
    }
    static string get(const(char)[] name)
    {
        auto result = map.get(cast(string)name, null);
        if (result is null)
            assert(0, "Unknown variable '" ~ name ~ "'");
        return result;
    }
    static string opDispatch(string name)() { return get(name); }
}

private alias requiredEnvVars = AliasSeq!(
    "MODEL", "RESULTS_DIR",
    "EXE", "OBJ",
    "DMD", "DFLAGS",
    "OS", "SEP", "DSEP",
);
private alias allVars = AliasSeq!(
    requiredEnvVars,
    "TEST_DIR", "TEST_NAME",
    "RESULTS_TEST_DIR",
    "OUTPUT_BASE", "EXTRA_FILES",
    "LIBEXT",
);

static foreach (var; allVars)
{
    mixin(`string ` ~ var ~ `() { return Vars.` ~ var ~ `; }`);
}

/// called from the dshell module to initialize environment
void dshellPrebuiltInit(string testDir, string testName)
{
    static foreach (var; requiredEnvVars)
    {
        mixin(`Vars.set("` ~ var ~ `", requireEnv("` ~ var ~ `"));`);
    }

    Vars.set("TEST_DIR", testDir);
    Vars.set("TEST_NAME", testName);
    // reference to the resulting test_dir folder, e.g .test_results/runnable
    Vars.set("RESULTS_TEST_DIR", buildPath(RESULTS_DIR, TEST_DIR));
    // reference to the resulting files without a suffix, e.g. test_results/runnable/test123import test);
    Vars.set("OUTPUT_BASE", buildPath(RESULTS_TEST_DIR, TEST_NAME));
    // reference to the extra files directory
    Vars.set("EXTRA_FILES", buildPath(TEST_DIR, "extra-files"));
    version (Windows)
    {
        Vars.set("LIBEXT", ".lib");
    }
    else
    {
        Vars.set("LIBEXT", ".a");
    }
}

private string requireEnv(string name)
{
    const result = environment.get(name, null);
    if (result is null)
    {
        writefln("Error: missing required environment variable '%s'", name);
        exit(1);
    }
    return result;
}

/// Remove one or more files
void rm(scope const(char[])[] args...)
{
    foreach (arg; args)
    {
        auto expanded = shellExpand(arg);
        if (exists(expanded))
        {
            writeln("rm '", expanded, "'");
            // Use loop to workaround issue in windows with removing
            // executables after running then
            for (int sleepMsecs = 10; ; sleepMsecs *= 2)
            {
                try {
                    std.file.remove(expanded);
                    break;
                } catch (Exception e) {
                    if (sleepMsecs >= 3000)
                        throw e;
                    Thread.sleep(dur!"msecs"(sleepMsecs));
                }
            }
        }
    }
}

/// Make all parent directories needed to create the given `filename`
void mkdirFor(string filename)
{
    auto dir = dirName(filename);
    if (!exists(dir))
    {
        writefln("[INFO] mkdir -p '%s'", dir);
        mkdirRecurse(dir);
    }
}

/**
Run the given command. The `tryRun` variants return the exit code, whereas the `run` variants
will assert on a non-zero exit code.
*/
auto tryRun(scope const(char[])[] args, File stdout = std.stdio.stdout, string[string] env = null)
{
    std.stdio.stdout.write("[RUN]");
    if (env)
    {
       foreach (pair; env.byKeyValue)
       {
           std.stdio.stdout.write(" ", pair.key, "=", pair.value);
       }
    }
    std.stdio.write(" ", escapeShellCommand(args));
    if (stdout != std.stdio.stdout)
    {
        std.stdio.stdout.write(" > ", stdout.name);
    }
    std.stdio.stdout.writeln();
    std.stdio.stdout.flush();
    auto proc = spawnProcess(args, stdin, stdout, std.stdio.stderr, env);
    return wait(proc);
}
/// ditto
void run(scope const(char[])[] args, File stdout = std.stdio.stdout, string[string] env = null)
{
    const exitCode = tryRun(args, stdout, env);
    if (exitCode != 0)
    {
        writefln("Error: last command exited with code %s", exitCode);
        assert(0, "last command failed");
    }
}
/// ditto
void run(string cmd, File stdout = std.stdio.stdout, string[string] env = null)
{
    // TODO: option to disable this?
    if (SEP != "/")
        cmd = cmd.replace("/", SEP);
    run(parseCommand(cmd), stdout, env);
}

/**
Parse the given string `s` as a command.  Performs BASH-like variable expansion.
*/
string[] parseCommand(string s)
{
    auto rawArgs = s.split();
    auto args = appender!(string[])();
    foreach (rawArg; rawArgs)
    {
        args.put(shellExpand(rawArg));
    }
    return args.data;
}

/// Expand the given string using BASH-like variable expansion.
string shellExpand(const(char)[] s)
{
    auto expanded = appender!(char[])();
    for (size_t i = 0; i < s.length;)
    {
        if (s[i] != '$')
        {
            expanded.put(s[i]);
            i++;
        }
        else
        {
            i++;
            assert(i < s.length, "lone '$' at end of string");
            auto start = i;
            if (s[i] == '{')
            {
                start++;
                for (;;)
                {
                    i++;
                    assert(i < s.length, "unterminated ${...");
                    if (s[i] == '}') break;
                }
                expanded.put(Vars.get(s[start .. i]));
                i++;
            }
            else
            {
                assert(validVarChar(s[i]), "invalid sequence $'" ~ s[i]);
                for (;;)
                {
                    i++;
                    if (i >= s.length || !validVarChar(s[i]))
                        break;
                }
                expanded.put(Vars.get(s[start .. i]));
            }
        }
    }
    auto result = expanded.data;
    return (result is null) ? "" : result.assumeUnique;
}

// [a-zA-Z0-9_]
private bool validVarChar(const char c)
{
    import std.ascii : isAlphaNum;
    return c.isAlphaNum || c == '_';
}

struct GrepResult
{
    string[] matches;
    void enforceMatches(string message)
    {
        if (matches.length == 0)
        {
            assert(0, message);
        }
    }
}

/**
grep the given `file` for the given `pattern`.
*/
GrepResult grep(string file, string pattern)
{
    const patternExpanded = shellExpand(pattern);
    const fileExpanded = shellExpand(file);
    writefln("[GREP] file='%s' pattern='%s'", fileExpanded, patternExpanded);
    return grepLines(File(fileExpanded, "r").byLine, patternExpanded);
}
/// ditto
GrepResult grep(GrepResult lastResult, string pattern)
{
    auto patternExpanded = shellExpand(pattern);
    writefln("[GREP] (%s lines from last grep) pattern='%s'", lastResult.matches.length, patternExpanded);
    return grepLines(lastResult.matches, patternExpanded);
}

private GrepResult grepLines(T)(T lineRange, string finalPattern)
{
    auto matches = appender!(string[])();
    foreach(line; lineRange)
    {
        if (matchFirst(line, finalPattern))
        {
            static if (is(typeof(lineRange.front()) == string))
                matches.put(line);
            else
                matches.put(line.idup);
        }
    }
    writefln("[GREP] matched %s lines", matches.data.length);
    return GrepResult(matches.data);
}

/**
read the the given `file` and remove \r and the compiler debug header.
*/
string readOutput(string file)
{
    string output = readText(file);
    output = std.string.replace(output, "\r", "");
    output = std.regex.replaceAll(output, regex(`^DMD v2\.[0-9]+.*\n? DEBUG\n`, "m"), "");
    return output;
}
