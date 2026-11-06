// https://github.com/dlang/dmd/issues/24085
module std.math.ctfe_log_extended;

// These declarations exercise the compiler builtins without a Phobos dependency.
real log(real);
real log2(real);
real log10(real);

static if (real.mant_dig == 64)
{
    enum tiny = real.min_normal * real.epsilon;
    enum nearOne = 1.0L + real.epsilon;

    bool close(real actual, real expected)
    {
        return actual >= expected - (expected < 0 ? -expected : expected) * 8 * real.epsilon &&
               actual <= expected + (expected < 0 ? -expected : expected) * 8 * real.epsilon;
    }

    static assert(close(log(real.max), 11356.52340629414394949L));
    static assert(close(log(tiny), -11398.80538430830061337L));
    static assert(close(log(nearOne), real.epsilon));
    static assert(close(log(1.0L - real.epsilon), -real.epsilon));
    static assert(close(log2(real.max), 16384.0L));
    static assert(log2(real.min_normal) == real.min_exp - 1);
    static assert(log2(tiny) == real.min_exp - real.mant_dig);
    static assert(close(log2(nearOne), 1.5641730975658777763e-19L));
    static assert(close(log2(1.0L - real.epsilon), -1.5641730975658777764451002732176633961e-19L));
    static assert(close(log10(tiny), -4950.4382786941707552899361237442878252L));
    static assert(close(log10(1.0L - real.epsilon), -4.7086302077797222205684739928068968727e-20L));
    static assert(close(log10(real.max), 4932.0754489586679024L));
    static assert(close(log10(nearOne), 4.70863020777972222005796328273633217538e-20L));
}

static foreach (fun; AliasSeq!(log, log2, log10))
{
    static assert(fun(1.0L) == 0);
    static assert(fun(0.0L) == -real.infinity);
    static assert(fun(-0.0L) == -real.infinity);
    static assert(fun(real.infinity) == real.infinity);
    static assert(fun(-1.0L) != fun(-1.0L));
    static assert(fun(real.nan) != fun(real.nan));
}
alias AliasSeq(T...) = T;
