// https://github.com/dlang/dmd/issues/21637
// ICE in tuple comparison with conditional expression

struct Date {
    short _year  = 1;
    ubyte _month;
    ubyte _day   = 1;

    this(int day) { }
}

struct Nullable(T){
    T t;
    short b;
}

struct DateRange {
    Nullable!Date end;
}

void main()
{
    auto thing = DateRange(
      (Date(1).tupleof == Date(2).tupleof) ? Nullable!Date() : Nullable!Date()
    );
}
