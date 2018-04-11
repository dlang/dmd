/**
HAR - Human Archive Format

https://github.com/marler8997/har

HAR is a simple format to represent multiple files in a single block of text, i.e.
---
--- main.d
import foo;
void main()
{
    foofunc();
}
--- foo.d
module foo;
void foofunc()
{
}
---
*/
module archive.har;

import std.typecons : Flag, Yes, No;
import std.array : Appender;
import std.format : format;
import std.string : startsWith, indexOf, stripRight;
import std.utf : decode, replacementDchar;
import std.path : dirName, buildPath;
import std.file : exists, isDir, mkdirRecurse;
import std.stdio : File;

class HarException : Exception
{
    this(string msg, string file, size_t line)
    {
        super(msg, file, line);
    }
}

struct HarExtractor
{
    string filenameForErrors;
    string outputDir;

    private bool verbose;
    private File verboseFile;

    bool dryRun;

    private size_t lineNumber;
    private void extractMkdir(string dir, Flag!"forEmptyDir" forEmptyDir)
    {
        if (exists(dir))
        {
            if (!isDir(dir))
            {
                if (forEmptyDir)
                    throw harFileException("cannot extract empty directory %s since it already exists as non-directory",
                        dir.formatDir);
                throw harFileException("cannot extract files to non-directory %s", dir.formatDir);
            }
        }
        else
        {
            if (verbose)
                verboseFile.writefln("mkdir %s", dir.formatDir);
            if (!dryRun)
                mkdirRecurse(dir);
        }
    }

    void enableVerbose(File verboseFile)
    {
        this.verbose = true;
        this.verboseFile = verboseFile;
    }

    void extractFromFile(T)(string harFilename, T fileInfoCallback)
    {
        this.filenameForErrors = harFilename;
        auto harFile = File(harFilename, "r");
        extract(harFile.byLine(Yes.keepTerminator), fileInfoCallback);
    }

    void extract(T, U)(T lineRange, U fileInfoCallback)
    {
        if (outputDir is null)
            outputDir = "";

        lineNumber = 1;
        if (lineRange.empty)
            throw harFileException("file is empty");

        auto line = lineRange.front;
        auto firstLineSpaceIndex = line.indexOf(' ');
        if (firstLineSpaceIndex <= 0)
            throw harFileException("first line does not start with a delimiter ending with a space");

        auto delimiter = line[0 .. firstLineSpaceIndex + 1].idup;

    LfileLoop:
        for (;;)
        {
            auto fileInfo = parseFileLine(line[delimiter.length .. $], delimiter[0]);
            auto fullFileName = buildPath(outputDir, fileInfo.filename);
            fileInfoCallback(fullFileName, fileInfo);

            if (fullFileName[$-1] == '/')
            {
                if (!dryRun)
                    extractMkdir(fullFileName, Yes.forEmptyDir);
                lineRange.popFront();
                if (lineRange.empty)
                    break;
                lineNumber++;
                line = lineRange.front;
                if (!line.startsWith(delimiter))
                    throw harFileException("expected delimiter after empty directory");
                continue;
            }

            {
                auto dir = dirName(fileInfo.filename);
                if (dir.length > 0)
                {
                    auto fullDir = buildPath(outputDir, dir);
                    extractMkdir(fullDir, No.forEmptyDir);
                }
            }
            if (verbose)
                verboseFile.writefln("creating %s", fullFileName.formatFile);
            {
                File currentOutputFile;
                if (!dryRun)
                    currentOutputFile = File(fullFileName, "w");
                scope(exit)
                {
                    if (!dryRun)
                        currentOutputFile.close();
                }
                for (;;)
                {
                    lineRange.popFront();
                    if (lineRange.empty)
                        break LfileLoop;
                    lineNumber++;
                    line = lineRange.front;
                    if (line.startsWith(delimiter))
                        break;
                    if (!dryRun)
                        currentOutputFile.write(line);
                }
            }
        }
    }
    private HarException harFileException(T...)(string fmt, T args) if (T.length > 0)
    {
        return harFileException(format(fmt, args));
    }
    private HarException harFileException(string msg)
    {
        return new HarException(msg, filenameForErrors, lineNumber);
    }

    FileProperties parseFileLine(const(char)[] line, char firstDelimiterChar)
    {
        if (line.length == 0)
            throw harFileException("missing filename");

        const(char)[] filename;
        const(char)[] rest;
        if (line[0] == '"')
        {
            size_t afterFileIndex;
            filename = parseQuotedFilename(line[1 .. $], &afterFileIndex);
            rest = line[afterFileIndex .. $];
        }
        else
        {
            filename = parseFilename(line);
            rest = line[filename.length .. $];
        }
        for (;;)
        {
            rest = skipSpaces(rest);
            if (rest.length == 0 || rest == "\n" || rest == "\r" || rest == "\r\n" || rest[0] == firstDelimiterChar)
                break;
            throw harFileException("properties not implemented '%s'", rest);
        }
        return FileProperties(filename);
    }

    void checkComponent(const(char)[] component)
    {
        if (component.length == 0)
            throw harFileException("invalid filename, contains double slash '//'");
        if (component == "..")
            throw harFileException("invalid filename, contains double dot '..' parent directory");
    }

    inout(char)[] parseFilename(inout(char)[] line)
    {
        if (line.length == 0 || isEndOfFileChar(line[0]))
            throw harFileException("missing filename");

        if (line[0] == '/')
            throw harFileException("absolute filenames are invalid");

        size_t start = 0;
        size_t next = 0;
        while (true)
        {
            auto cIndex = next;
            auto c = decode!(Yes.useReplacementDchar)(line, next);
            if (c == replacementDchar)
                throw harFileException("invalid utf8 sequence");

            if (c == '/')
            {
                checkComponent(line[start .. cIndex]);
                if (next >= line.length)
                    return line[0 .. next];
                start = next;
            }
            else if (isEndOfFileChar(c))
            {
                checkComponent(line[start .. cIndex]);
                return line[0 .. cIndex];
            }

            if (next >= line.length)
            {
                checkComponent(line[start .. next]);
                return line[0 ..next];
            }
        }
    }

    inout(char)[] parseQuotedFilename(inout(char)[] line, size_t* afterFileIndex)
    {
        if (line.length == 0)
            throw harFileException("filename missing end-quote");
        if (line[0] == '"')
            throw harFileException("empty filename");
        if (line[0] == '/')
            throw harFileException("absolute filenames are invalid");

        size_t start = 0;
        size_t next = 0;
        while(true)
        {
            auto cIndex = next;
            auto c = decode!(Yes.useReplacementDchar)(line, next);
            if (c == replacementDchar)
                throw harFileException("invalid utf8 sequence");

            if (c == '/')
            {
                checkComponent(line[start .. cIndex]);
                start = next;
            }
            else if (c == '"')
            {
                checkComponent(line[start .. cIndex]);
                *afterFileIndex = next + 1;
                return line[0 .. cIndex];
            }
            if (next >= line.length)
                throw harFileException("filename missing end-quote");
        }
    }
}

private inout(char)[] skipSpaces(inout(char)[] str)
{
    size_t i = 0;
    for (; i < str.length; i++)
    {
        if (str[i] != ' ')
            break;
    }
    return str[i .. $];
}

private bool isEndOfFileChar(C)(const(C) c)
{
    return c == '\n' || c == ' ' || c == '\r';
}

struct FileProperties
{
    const(char)[] filename;
}

auto formatDir(const(char)[] dir)
{
    if (dir.length == 0)
        dir = ".";

    return formatQuotedIfSpaces(dir);
}
auto formatFile(const(char)[] file)
  in { assert(file.length > 0); } do
{
    return formatQuotedIfSpaces(file);
}

// returns a formatter that will print the given string.  it will print
// it surrounded with quotes if the string contains any spaces.
auto formatQuotedIfSpaces(T...)(T args)
if (T.length > 0)
{
    struct Formatter
    {
        T args;
        void toString(scope void delegate(const(char)[]) sink) const
        {
            import std.string : indexOf;
            bool useQuotes = false;
            foreach (arg; args)
            {
                if (arg.indexOf(' ') >= 0)
                {
                    useQuotes = true;
                    break;
                }
            }

            if (useQuotes)
                sink(`"`);
            foreach (arg; args)
                sink(arg);
            if (useQuotes)
                sink(`"`);
        }
    }
    return Formatter(args);
}
