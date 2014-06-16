import std.datetime;

void main()
{
    DateTime[] datetimes = [
        DateTime(Date(2014, 5, 21)),
        DateTime(Date(2014, 5, 20)),
        DateTime(Date(2014, 5, 23)),
        DateTime(Date(2014, 5, 22)),
    ];

    DateTime[] expected = [
        DateTime(Date(2014, 5, 20)),
        DateTime(Date(2014, 5, 21)),
        DateTime(Date(2014, 5, 22)),
        DateTime(Date(2014, 5, 23)),
    ];

    assert(datetimes.sort == expected);
}
