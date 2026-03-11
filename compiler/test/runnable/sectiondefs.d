/*
EXTRA_SOURCES: extra-files/sectiondefs.d
EXTRA_FILES: extra-files/sectiondefs.d
REQUIRED_ARGS(win): -L/INCREMENTAL:NO
*/
// Incremental linking must be turned off, or it will add padding.
module sectiondefs;
import core.attribute;

version (linux)
    version = ELF;
else version (FreeBSD)
    version = ELF;
else version (OpenBSD)
    version = ELF;
else version (NetBSD)
    version = ELF;

version(Windows)
    enum PlatformEntryName(string Name) = "." ~ Name ~ "$N";
else
    enum PlatformEntryName(string Name) = Name;

mixin template SectionRange(string SectionName, Type)
{
    version (OSX)
    {
        enum Segment = (is(Type == const) || is(Type == immutable)) ? "__TEXT" : "__DATA";

        extern(C) extern __gshared
        {
            pragma(mangle, "section$start$" ~ Segment ~ "$" ~ SectionName)
            Type start;
            pragma(mangle, "section$end$" ~ Segment ~ "$" ~ SectionName)
            Type end;
        }
    }
    else version (ELF)
    {
        extern(C) extern __gshared
        {
            pragma(mangle, "__start_" ~ SectionName)
            Type start;
            pragma(mangle, "__stop_" ~ SectionName)
            Type end;
        }
    }
    else version (Windows)
    {
        __gshared
        {
            @section("." ~ SectionName ~ "$A")
            Type _head;

            @section("." ~ SectionName ~ "$Z")
            Type _tail;
        }

        Type* start()
        {
            return &_head + 1;
        }

        Type* end()
        {
            return &_tail;
        }
    }

    Type[] range()
    {
        version (Windows)
            return start()[0 .. end() - start()];
        else
            return (&start)[0 .. (&end - &start)];
    }
}

mixin SectionRange!("myInts", int) myIntsSection;
mixin SectionRange!("my8Ints", int[8]) my8IntsSection;

@section(PlatformEntryName!"myInts")
__gshared int anInt = 2;

@section(PlatformEntryName!"my8Ints")
__gshared int[8] an8Int = [46, 92, 11, 7, 2, 55, 33, 22];

void main()
{
    //int dummy = anInt, dummy8 = an8Int[0];

    version(none)
    {
        import core.stdc.stdio;
        printf("=========== sectiondefs tests ================\n");
        printf("myInts %p %zd\n", myIntsSection.range.ptr, myIntsSection.range.length);
        printf("my8IntsSection %p %zd\n", my8IntsSection.range.ptr, my8IntsSection.range.length);

        version (Windows)
            printf("start %p %p\n", myIntsSection.start(), my8IntsSection.start());
        else
            printf("start %p %p\n", &myIntsSection.start, &my8IntsSection.start);

        version (Windows)
            printf("end %p %p\n", myIntsSection.end(), my8IntsSection.end());
        else
            printf("end %p %p\n", &myIntsSection.end, &my8IntsSection.end);

        printf("- ");
        foreach (v; myIntsSection.range)
           printf("%d, ", v);
        printf("\n-\n");
        foreach(v; my8IntsSection.range)
            printf(" - [%d, %d, %d, %d, %d, %d, %d, %d],\n", v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7]);
        printf("\n");
    }

    assert(myIntsSection.range == [2, 9] || myIntsSection.range == [9, 2]);

    assert(my8IntsSection.range == [
        [46, 92, 11, 7, 2, 55, 33, 22], [64, 72, 9, 81, 21, 59, 45, 2]
    ] || my8IntsSection.range == [
        [64, 72, 9, 81, 21, 59, 45, 2], [46, 92, 11, 7, 2, 55, 33, 22]
    ]);
}
