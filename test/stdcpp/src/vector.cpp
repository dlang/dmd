#include <vector>

int fromC_val(std::vector<int>);
int fromC_ref(const std::vector<int>&);

int sumOfElements_ref(const std::vector<int>& arr)
{
    int r = 0;
    for (std::size_t i = 0; i < arr.size(); ++i)
        r += arr[i];
    return r;
}

int sumOfElements_val(std::vector<int> arr)
{
    return sumOfElements_ref(arr) + fromC_ref(arr) + fromC_val(arr);
}
