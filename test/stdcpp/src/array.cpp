#include <array>

std::array<int, 5> fromC_val(std::array<int, 5>);
std::array<int, 5>& fromC_ref(std::array<int, 5>&);

std::array<int, 5>& sumOfElements_ref(std::array<int, 5>& arr)
{
    int r = 0;
    for (size_t i = 0; i < arr.size(); ++i)
        r += arr[i];
    arr.fill(r);
    return arr;
}

std::array<int, 5> sumOfElements_val(std::array<int, 5> arr)
{
    int r = sumOfElements_ref(arr)[0] + fromC_ref(arr)[0] + fromC_val(arr)[0];
    arr.fill(r);
    return arr;
}
