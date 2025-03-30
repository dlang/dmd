#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT
#endif

class EXPORT C22323
{
public:
    C22323();
    virtual ~C22323();

    static int ctorCount;
    static int dtorCount;
};

int C22323::ctorCount;
int C22323::dtorCount;

C22323::C22323()
{
    ctorCount++;
}

C22323::~C22323()
{
    dtorCount++;
}

struct EXPORT S22323
{
public:
    S22323(int dummy);
    ~S22323();

    static int ctorCount;
    static int dtorCount;
};

int S22323::ctorCount;
int S22323::dtorCount;

S22323::S22323(int dummy)
{
    ctorCount++;
}

S22323::~S22323()
{
    dtorCount++;
}

// https://issues.dlang.org/show_bug.cgi?id=19660
extern "C"
{
    EXPORT int someValue19660 = 0xF1234;
    EXPORT void setSomeValue19660(int v)
    {
        someValue19660 = v;
    }
    EXPORT int getSomeValue19660(void)
    {
        return someValue19660;
    }
}

EXPORT int someValueCPP19660 = 0xF1234;
EXPORT void setSomeValueCPP19660(int v)
{
    someValueCPP19660 = v;
}
EXPORT int getSomeValueCPP19660(void)
{
    return someValueCPP19660;
}
