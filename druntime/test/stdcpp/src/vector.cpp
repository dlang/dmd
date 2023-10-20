#include <vector>

extern int vectorTest_numAllocated;

struct NotPOD
{
    NotPOD() = delete;
    NotPOD(int a)
    {
        for (int i = 0; i < 5; ++i)
            x[i] = a + i + 1;
        wasInit = true;
        ++vectorTest_numAllocated;
    }
    NotPOD(const NotPOD& rh)
    {
        for (int i = 0; i < 5; ++i)
            x[i] = rh.x[i];
        wasInit = rh.wasInit;
        if (rh.wasInit)
            ++vectorTest_numAllocated;
    }
    NotPOD(NotPOD&& rh)
    {
        for (int i = 0; i < 5; ++i)
            x[i] = rh.x[i];
        wasInit = rh.wasInit;
        rh.wasInit = false;
    }
    ~NotPOD()
    {
        if (wasInit)
            --vectorTest_numAllocated;
    }

    int x[5];
    bool wasInit;
};

int fromC_val(std::vector<int>);
int fromC_ref(const std::vector<int>&);
int fromC_nonPod_val(std::vector<NotPOD>);

int sumOfElements_ref(const std::vector<int>& vec)
{
    int r = 0;
    for (std::size_t i = 0; i < vec.size(); ++i)
        r += vec[i];
    return r;
}

int sumOfElements_val(std::vector<int> vec)
{
    return sumOfElements_ref(vec) + fromC_ref(vec) + fromC_val(vec);
}

int nonPod_val(std::vector<NotPOD> vec)
{
    return vec.size() == 3 && vec[2].x[0] == 4 && fromC_nonPod_val(vec);
}
