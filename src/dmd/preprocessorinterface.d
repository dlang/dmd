/*
    This module implements the code that dmd uses to talk
    to the C preprocessor.

    It does not implement *a* C preprocessor (yet?).
 */
module dmd.preprocessorinterface;
import dmd.root.optional;
import dmd.errors;
import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import core.sys.posix.stdio;
import core.sys.posix.stdlib;
import core.sys.posix.unistd;
import core.sys.windows.winbase;
import core.sys.windows.windef;
import dmd.arraytypes;
import dmd.root.filename;
import dmd.target;
//This is currently an ugly global variable because it can't go in globals just yet.
__gshared PreProcessorStore preprocessorStore;
//They aren't registered implicitly just in case consumers of the frontend don't want it
void registerDmdPreprocessors(ref PreProcessorStore x)
{
    x.register(new GNUPreprocessor(false));
}
/*
Things raised by Iain in an email:

As far as calling a preprocessor is concerned:
- It does something different to what you expect (contrived).
    No idea
- It's the wrong version of cpp for your toolchain.
    Currently configurable by settings CC=xyz
- It's the wrong sysroot of cpp for your toolchain.
- It's the wrong cross of cpp for your toolchain.
*/

struct Macro
{
    string name;
    string definition;
}
//Contains state from the preprocessor to be returned.
struct PreprocessorResult
{
    ///Where the preprocessed file went
    char[] resultPath;
    ///Macros captured at the end of preprocessing e.g. from gcc/clang -dM
    Macro[] macros; //Currently not filled
}
/++
    Very abstract interface for C preprocessors.

    Idea being that certain consumers of the dmd frontend can
    basically do whatever they want wrt preprocessing.

    Its form is not final.
 +/
public interface Preprocessor
{
    string name();
    ///
    Optional!PreprocessorResult preprocess(const char[] path);
    /+
        Basic integrity check to see if the preprocessor is actually there.

        This is basically intended for windows where it's much more likely to have
        weird things happen than a *nix based operating system.
    +/
    bool integrity();
    /+
        Attempt to score a preprocessor based on it's compatiblity
        with the Franken-C the compiler is trying to target.

        Return a greater score for a better match (details somewhat hazy)
        or -1 it won't work.

        This could well be replaced by something more complicated in the future
        but it might be good enough for now as long as things that don't matter
        aren't counted by mistake.

        The method is not-const so the preprocessor can mutate itself.
    +/
    ScoreAccum targetSupportScore(const ref Target matchThis, ScoreAccum x);
}
///The compiler keeps track of available preprocessors here.
struct PreProcessorStore
{
    import dmd.root.array : Array;
    Array!(Preprocessor) store;
    ///
    void register(Preprocessor pre)
    {
        store.push(pre);
    }
    ///
    Preprocessor lookForCompatiblePreprocessor(const ref Target targetSpec, ref string[] failures)
    {
        Preprocessor best = null;
        int bestScoreSoFar = -1;
        foreach(Preprocessor val; store)
        {
            //declared scope here rather than down the stack so it's still cheap
            //but can be returned.
            scope ScoreAccum x = new ScoreAccum;
            const res = val.targetSupportScore(targetSpec, x);
            const score = res.score;
            if(score > bestScoreSoFar)
            {
                best = val;
                bestScoreSoFar = score;
            } else if (score < 0) {
                foreach(reason; res.failureReasons)
                {
                    failures ~= (val.name ~ ": " ~ reason);
                }
            }
        }
        return best;
    }
}



///Things common to preprocessors supported by dmd
abstract class DmdPreprocessorCommon : Preprocessor
{
    ///The compatibility header in druntime
    static const(char)* compatibilityHeader = "importc.h";
    /+
        ImportC does not import all features of all C compilers (this set of unsupported features will eventually
        solely contain builtins for that compiler-target pair), this requires the use of a dmd-specific header file
        to remove or translate certain constructs into forms dmd can parse.

        This feature is also useful for C development in general however ImportC is not strictly intended to be a C compiler.
    +/
    Strings includeInAll;

}

extern(C)
int mkstemps(char * t, int suffixlen);
///Use GCC (or GCC compatible preprocessor) to preprocess C files.
class GNUPreprocessor : DmdPreprocessorCommon
{
    string name()
    {
        return "GCC";
    }
    bool useGNUDefines = false;
    string failString;
    this(bool useGNUDefines)
    {
        this.useGNUDefines = useGNUDefines;
    }
    Optional!PreprocessorResult preprocess(const(char)[] path)
    {
        typeof(return) val;
        Strings preprocessorArgs;
        auto ptr = getenv("CC");
        //If there's an envionment variable set then use it
        const(char)* gcc = getenv("CC") ? ptr : "cc";
        import core.stdc.string;
        char[] tmpFilePath = "/tmp/dmd_importc_tmp_XXXXXX.c".dup ~ '\0';
        //TODO: Move somewhere else and make it host agnostic
        int tmpRet = mkstemps(tmpFilePath.ptr, 2);
        if (tmpRet == -1)
        {
            import core.stdc.errno;
            printf("%s -> %s\n", tmpFilePath.ptr, strerror(errno));
            assert(0);
        }
        //printf("CC=%s\n", gcc);
        with(preprocessorArgs) {
            push(gcc);
            if (useGNUDefines)
            {
                push("-undef");
            }
            foreach(str; includeInAll) {
                push("-include");
                push(str);
            }
            push((path ~ '\0').ptr);
            push("-E");
            push("-o");
            push(tmpFilePath.ptr);
            push(null);
        }
        //printf("C=%s %s\n", gcc, preprocessorArgs.toChars());
        pid_t childpid;
        childpid = vfork();
        if (childpid == 0)
        {
            int res = execvp(gcc, preprocessorArgs.tdata());
            assert(res != -1);
            perror(gcc); // failed to execute
            _exit(-1);
        }
        else if (childpid == -1)
        {
            perror("dmd failed to invoke the gcc preprocesor");
            return val;
        }
        int status;
        //wait for it
        waitpid(childpid, &status, 0);
        //no error checking yet
        Optional!PreprocessorResult hack;
        return status == 0 ? typeof(return)(PreprocessorResult(tmpFilePath)) : hack;
    }
    bool integrity()
    {
        return true;
    }
    ScoreAccum targetSupportScore(const ref Target input, ScoreAccum x)
    {
        assert(x);

        with(input)
        //With the exception of supporting windows these should become maybes.
        return
        x.
            must((){
                import dmd.globals : global;
                if(auto path = FileName.searchPath(global.path, compatibilityHeader, false)) {
                    this.includeInAll.push(path);
                    import std.stdio;
                    return true;
                } else {
                    return false;
                }
            }(), "the importc compatibility header `importc.h` could not be found")
            .must(os == Target.OS.linux, "can only preprocess for linux targets")
            .must(c.runtime == c.Runtime.Glibc)
            .must(c.bitFieldStyle == c.BitFieldStyle.Gcc_Clang);
    }
}

private class ScoreAccum
{
    ScoreAccum must(lazy bool x, string reason = null)
    {
        if (x) {
            //If the score is already -1 (failed) then don't increment it
            this.score += this.score >= 0 ? 1 : 0;
        } else {
            score = -1;
            //For an errorSupplemental
            if (reason)
                this.failureReasons ~= reason;
        }
        return this;
    }
    string[] failureReasons;
    int score = 0;
}
