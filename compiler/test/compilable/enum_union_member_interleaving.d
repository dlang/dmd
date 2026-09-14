enum union InterleavedCases
{
    alias BeforeCases = int;

    case Data(int);

    enum int revision = 1;

    case Ping(long);
    alias BetweenCases = long;

    case Reset(short);
}

enum union InterleavedCaseList
{
    alias BeforeList = int;

    case First(), Second();

    static int helper() { return 42; }

    case Third();
}

static assert(InterleavedCases.revision == 1);
static assert(InterleavedCaseList.helper() == 42);