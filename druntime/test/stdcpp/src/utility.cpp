#include <stddef.h>
#include <utility>

extern int opt_pairRefCount;

struct Elaborate
{
    bool valid;
    int buffer[16];

    Elaborate(const Elaborate& rh)
    {
        valid = rh.valid;
        if (rh.valid)
        {
            ++opt_pairRefCount;
            for (size_t i = 0; i < 16; ++i)
                buffer[i] = rh.buffer[i];
        }
    }
    ~Elaborate()
    {
        if (valid)
            --opt_pairRefCount;
    }
};

typedef std::pair<int, float> SimplePair;
typedef std::pair<int, Elaborate> ElaboratePair;


int fromC_val(SimplePair, SimplePair&, ElaboratePair, ElaboratePair&);

int callC_val(SimplePair a1, SimplePair& a2, ElaboratePair a3, ElaboratePair& a4)
{
    return fromC_val(a1, a2, a3, a4);
}
