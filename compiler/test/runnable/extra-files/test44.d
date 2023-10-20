
import imports.test44a;

const char[][7] DAY_NAME = [
        DAY.SUN: "sunday", "monday", "tuesday", "wednesday",
          "thursday", "friday", "saturday"
];


void main()
{
    assert(DAY_NAME[DAY.SUN] == "sunday");
    assert(DAY_NAME[DAY.MON] == "monday");
    assert(DAY_NAME[DAY.TUE] == "tuesday");
    assert(DAY_NAME[DAY.WED] == "wednesday");
    assert(DAY_NAME[DAY.THU] == "thursday");
    assert(DAY_NAME[DAY.FRI] == "friday");
    assert(DAY_NAME[DAY.SAT] == "saturday");
}
