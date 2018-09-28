#include <optional>

extern int opt_refCount;

struct Complex
{
    bool valid = false;

    int buffer[16] = { 10 };

    Complex() = delete;
    Complex(const Complex& rh)
    {
        valid = rh.valid;
        if (rh.valid)
        {
            ++opt_refCount;
            for (int i = 0; i < 16; ++i)
                buffer[i] = rh.buffer[i];
        }
    }
    ~Complex()
    {
        if (valid)
            --opt_refCount;
    }
};

int fromC_val(bool, std::optional<int>, const std::optional<int>&,
    std::optional<void*>, const std::optional<void*>&,
    std::optional<Complex>, const std::optional<Complex>&);

int callC_val(bool set, std::optional<int> a1, const std::optional<int>& a2,
    std::optional<void*> a3, const std::optional<void*>& a4,
    std::optional<Complex> a5, const std::optional<Complex>& a6)
{
    if (set)
    {
        if (!a1 || a1.value() != 10) return 1;
        if (!a2 || a2.value() != 10) return 1;
        if (!a3 || a3.value() != (void*)0x1234) return 1;
        if (!a4 || a4.value() != (void*)0x1234) return 1;
        if (!a5 || a5.value().buffer[0] != 20 || a5.value().buffer[15] != 20) return 1;
        if (!a6 || a6.value().buffer[0] != 20 || a6.value().buffer[15] != 20) return 1;
    }
    else
    {
        if (a1 || a2 || a3 || a4 || a5 || a6)
            return 1;
    }

    return fromC_val(set, a1, a2, a3, a4, a5, a6);
}
