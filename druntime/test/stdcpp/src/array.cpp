#include <array>

std::array<int, 5> fromC_val(std::array<int, 5>);
std::array<int, 5>& fromC_ref(std::array<int, 5>&);

std::array<int, 5>& sumOfElements_ref(std::array<int, 5>& arr)
{
    int r = 0;
    for (std::size_t i = 0; i < arr.size(); ++i)
        r += arr[i];
    arr.fill(r);
    return arr;
}

std::array<int, 5> sumOfElements_val(std::array<int, 5> arr)
{
    int r = 0;
    r += sumOfElements_ref(arr)[0];
    r += fromC_ref(arr)[0];
    r += fromC_val(arr)[0];
    arr.fill(r);
    return arr;
}
