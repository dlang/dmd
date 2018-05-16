
import core.stdc.stdint;

extern (C++):

void int8(int8_t i) { }
void uint8(uint8_t i) { }

void int16(int16_t i) { }
void uint16(uint16_t i) { }

void int32(int32_t i) { }
void uint32(uint32_t i) { }

void int64(int64_t i) { }
void uint64(uint64_t i) { }

void int_least8(int_least8_t i) { }
void uint_least8(uint_least8_t i) { }

void int_least16(int_least16_t i) { }
void uint_least16(uint_least16_t i) { }

void int_least32(int_least32_t i) { }
void uint_least32(uint_least32_t i) { }

void int_least64(int_least64_t i) { }
void uint_least64(uint_least64_t i) { }

void int_fast8(int_fast8_t i) { }
void uint_fast8(uint_fast8_t i) { }

void int_fast16(int_fast16_t i) { }
void uint_fast16(uint_fast16_t i) { }

void int_fast32(int_fast32_t i) { }
void uint_fast32(uint_fast32_t i) { }

void int_fast64(int_fast64_t i) { }
void uint_fast64(uint_fast64_t i) { }

void intptr(intptr_t i) { }
void uintptr(uintptr_t i) { }

void intmax(intmax_t i) { }
void uintmax(uintmax_t i) { }

version (Win32)
{
    static assert(int8.mangleof         == "?int8@@YAXC@Z");
    static assert(uint8.mangleof        == "?uint8@@YAXE@Z");
    static assert(int16.mangleof        == "?int16@@YAXF@Z");
    static assert(uint16.mangleof       == "?uint16@@YAXG@Z");
    static assert(int32.mangleof        == "?int32@@YAXJ@Z");
    static assert(uint32.mangleof       == "?uint32@@YAXK@Z");
    static assert(int64.mangleof        == "?int64@@YAX_J@Z");
    static assert(uint64.mangleof       == "?uint64@@YAX_K@Z");

    static assert(int_least8.mangleof   == "?int_least8@@YAXC@Z");
    static assert(uint_least8.mangleof  == "?uint_least8@@YAXE@Z");
    static assert(int_least16.mangleof  == "?int_least16@@YAXF@Z");
    static assert(uint_least16.mangleof == "?uint_least16@@YAXG@Z");
    static assert(int_least32.mangleof  == "?int_least32@@YAXJ@Z");
    static assert(uint_least32.mangleof == "?uint_least32@@YAXK@Z");
    static assert(int_least64.mangleof  == "?int_least64@@YAX_J@Z");
    static assert(uint_least64.mangleof == "?uint_least64@@YAX_K@Z");

    static assert(int_fast8.mangleof    == "?int_fast8@@YAXC@Z");
    static assert(uint_fast8.mangleof   == "?uint_fast8@@YAXE@Z");
    static assert(int_fast16.mangleof   == "?int_fast16@@YAXH@Z");
    static assert(uint_fast16.mangleof  == "?uint_fast16@@YAXI@Z");
    static assert(int_fast32.mangleof   == "?int_fast32@@YAXJ@Z");
    static assert(uint_fast32.mangleof  == "?uint_fast32@@YAXK@Z");
    static assert(int_fast64.mangleof   == "?int_fast64@@YAX_J@Z");
    static assert(uint_fast64.mangleof  == "?uint_fast64@@YAX_K@Z");

    static assert(intptr.mangleof       == "?intptr@@YAXH@Z");
    static assert(uintptr.mangleof      == "?uintptr@@YAXI@Z");
    static assert(intmax.mangleof       == "?intmax@@YAX_J@Z");
    static assert(uintmax.mangleof      == "?uintmax@@YAX_K@Z");
}
else version (Win64)
{
    static assert(int8.mangleof         ==  "?int8@@YAXC@Z");
    static assert(uint8.mangleof        == "?uint8@@YAXE@Z");
    static assert(int16.mangleof        ==  "?int16@@YAXF@Z");
    static assert(uint16.mangleof       == "?uint16@@YAXG@Z");
    static assert(int32.mangleof        ==  "?int32@@YAXH@Z");
    static assert(uint32.mangleof       == "?uint32@@YAXI@Z");
    static assert(int64.mangleof        ==  "?int64@@YAX_J@Z");
    static assert(uint64.mangleof       == "?uint64@@YAX_K@Z");

    static assert(int_least8.mangleof   ==  "?int_least8@@YAXC@Z");
    static assert(uint_least8.mangleof  == "?uint_least8@@YAXE@Z");
    static assert(int_least16.mangleof  ==  "?int_least16@@YAXF@Z");
    static assert(uint_least16.mangleof == "?uint_least16@@YAXG@Z");
    static assert(int_least32.mangleof  ==  "?int_least32@@YAXH@Z");
    static assert(uint_least32.mangleof == "?uint_least32@@YAXI@Z");
    static assert(int_least64.mangleof  ==  "?int_least64@@YAX_J@Z");
    static assert(uint_least64.mangleof == "?uint_least64@@YAX_K@Z");

    static assert(int_fast8.mangleof    ==  "?int_fast8@@YAXD@Z");   // char
    static assert(uint_fast8.mangleof   == "?uint_fast8@@YAXE@Z");   // unsigned char
    static assert(int_fast16.mangleof   ==  "?int_fast16@@YAXH@Z");  // int
    static assert(uint_fast16.mangleof  == "?uint_fast16@@YAXI@Z");  // unsigned int
    static assert(int_fast32.mangleof   ==  "?int_fast32@@YAXH@Z");  // int
    static assert(uint_fast32.mangleof  == "?uint_fast32@@YAXI@Z");  // unsigned int
    static assert(int_fast64.mangleof   ==  "?int_fast64@@YAX_J@Z"); // _Longlong
    static assert(uint_fast64.mangleof  == "?uint_fast64@@YAX_K@Z"); // _ULonglong

    static assert(intptr.mangleof       ==  "?intptr@@YAX_J@Z");
    static assert(uintptr.mangleof      == "?uintptr@@YAX_K@Z");
    static assert(intmax.mangleof       ==  "?intmax@@YAX_J@Z");
    static assert(uintmax.mangleof      == "?uintmax@@YAX_K@Z");
}
else version (OSX)
{
  version (D_LP64)
  {
    static assert(int8.mangleof         == "_Z4int8a");
    static assert(uint8.mangleof        == "_Z5uint8h");
    static assert(int16.mangleof        == "_Z5int16s");
    static assert(uint16.mangleof       == "_Z6uint16t");
    static assert(int32.mangleof        == "_Z5int32i");
    static assert(uint32.mangleof       == "_Z6uint32j");
    static assert(int64.mangleof        == "_Z5int64x");
    static assert(uint64.mangleof       == "_Z6uint64y");

    static assert(int_least8.mangleof    == "_Z10int_least8a");
    static assert(uint_least8.mangleof  == "_Z11uint_least8h");
    static assert(int_least16.mangleof  == "_Z11int_least16s");
    static assert(uint_least16.mangleof == "_Z12uint_least16t");
    static assert(int_least32.mangleof  == "_Z11int_least32i");
    static assert(uint_least32.mangleof == "_Z12uint_least32j");
    static assert(int_least64.mangleof  == "_Z11int_least64x");
    static assert(uint_least64.mangleof == "_Z12uint_least64y");

    static assert(int_fast8.mangleof    == "_Z9int_fast8a");
    static assert(uint_fast8.mangleof   == "_Z10uint_fast8h");
    static assert(int_fast16.mangleof   == "_Z10int_fast16s");
    static assert(uint_fast16.mangleof  == "_Z11uint_fast16t");
    static assert(int_fast32.mangleof   == "_Z10int_fast32i");
    static assert(uint_fast32.mangleof  == "_Z11uint_fast32j");
    static assert(int_fast64.mangleof   == "_Z10int_fast64x");
    static assert(uint_fast64.mangleof  == "_Z11uint_fast64y");

    static assert(intptr.mangleof       == "_Z6intptrl");
    static assert(uintptr.mangleof      == "_Z7uintptrm");
    static assert(intmax.mangleof       == "_Z6intmaxl");
    static assert(uintmax.mangleof      == "_Z7uintmaxm");
  }
  else
  {
    static assert(int8.mangleof         == "_Z4int8a");
    static assert(uint8.mangleof        == "_Z5uint8h");
    static assert(int16.mangleof        == "_Z5int16s");
    static assert(uint16.mangleof       == "_Z6uint16t");
    static assert(int32.mangleof        == "_Z5int32i");
    static assert(uint32.mangleof       == "_Z6uint32j");
    static assert(int64.mangleof        == "_Z5int64x");
    static assert(uint64.mangleof       == "_Z6uint64y");

    static assert(int_least8.mangleof    == "_Z10int_least8a");
    static assert(uint_least8.mangleof  == "_Z11uint_least8h");
    static assert(int_least16.mangleof  == "_Z11int_least16s");
    static assert(uint_least16.mangleof == "_Z12uint_least16t");
    static assert(int_least32.mangleof  == "_Z11int_least32i");
    static assert(uint_least32.mangleof == "_Z12uint_least32j");
    static assert(int_least64.mangleof  == "_Z11int_least64x");
    static assert(uint_least64.mangleof == "_Z12uint_least64y");

    static assert(int_fast8.mangleof    == "_Z9int_fast8a");
    static assert(uint_fast8.mangleof   == "_Z10uint_fast8h");
    static assert(int_fast16.mangleof   == "_Z10int_fast16s");
    static assert(uint_fast16.mangleof  == "_Z11uint_fast16t");
    static assert(int_fast32.mangleof   == "_Z10int_fast32i");
    static assert(uint_fast32.mangleof  == "_Z11uint_fast32j");
    static assert(int_fast64.mangleof   == "_Z10int_fast64x");
    static assert(uint_fast64.mangleof  == "_Z11uint_fast64y");

    static assert(intptr.mangleof       == "_Z6intptrl");
    static assert(uintptr.mangleof      == "_Z7uintptrm");
    static assert(intmax.mangleof       == "_Z6intmaxx");
    static assert(uintmax.mangleof      == "_Z7uintmaxy");
  }
}
else version (Posix)
{
  version (D_LP64)
  {
    static assert(int8.mangleof         == "_Z4int8a");
    static assert(uint8.mangleof        == "_Z5uint8h");
    static assert(int16.mangleof        == "_Z5int16s");
    static assert(uint16.mangleof       == "_Z6uint16t");
    static assert(int32.mangleof        == "_Z5int32i");
    static assert(uint32.mangleof       == "_Z6uint32j");
    static assert(int64.mangleof        == "_Z5int64l");
    static assert(uint64.mangleof       == "_Z6uint64m");

    static assert(int_least8.mangleof   == "_Z10int_least8a");
    static assert(uint_least8.mangleof  == "_Z11uint_least8h");
    static assert(int_least16.mangleof  == "_Z11int_least16s");
    static assert(uint_least16.mangleof == "_Z12uint_least16t");
    static assert(int_least32.mangleof  == "_Z11int_least32i");
    static assert(uint_least32.mangleof == "_Z12uint_least32j");
    static assert(int_least64.mangleof  == "_Z11int_least64l");
    static assert(uint_least64.mangleof == "_Z12uint_least64m");

    static assert(int_fast8.mangleof    == "_Z9int_fast8a");
    static assert(uint_fast8.mangleof   == "_Z10uint_fast8h");
    static assert(int_fast16.mangleof   == "_Z10int_fast16l");
    static assert(uint_fast16.mangleof  == "_Z11uint_fast16m");
    static assert(int_fast32.mangleof   == "_Z10int_fast32l");
    static assert(uint_fast32.mangleof  == "_Z11uint_fast32m");
    static assert(int_fast64.mangleof   == "_Z10int_fast64l");
    static assert(uint_fast64.mangleof  == "_Z11uint_fast64m");

    static assert(intptr.mangleof       == "_Z6intptrl");
    static assert(uintptr.mangleof      == "_Z7uintptrm");
    static assert(intmax.mangleof       == "_Z6intmaxl");
    static assert(uintmax.mangleof      == "_Z7uintmaxm");
  }
  else
  {
    static assert(int8.mangleof         == "_Z4int8a");
    static assert(uint8.mangleof        == "_Z5uint8h");
    static assert(int16.mangleof        == "_Z5int16s");
    static assert(uint16.mangleof       == "_Z6uint16t");
    static assert(int32.mangleof        == "_Z5int32i");
    static assert(uint32.mangleof       == "_Z6uint32j");
    static assert(int64.mangleof        == "_Z5int64x");
    static assert(uint64.mangleof       == "_Z6uint64y");

    static assert(int_least8.mangleof   == "_Z10int_least8a");
    static assert(uint_least8.mangleof  == "_Z11uint_least8h");
    static assert(int_least16.mangleof  == "_Z11int_least16s");
    static assert(uint_least16.mangleof == "_Z12uint_least16t");
    static assert(int_least32.mangleof  == "_Z11int_least32i");
    static assert(uint_least32.mangleof == "_Z12uint_least32j");
    static assert(int_least64.mangleof  == "_Z11int_least64x");
    static assert(uint_least64.mangleof == "_Z12uint_least64y");

    static assert(int_fast8.mangleof    == "_Z9int_fast8a");
    static assert(uint_fast8.mangleof   == "_Z10uint_fast8h");
    static assert(int_fast16.mangleof   == "_Z10int_fast16i");
    static assert(uint_fast16.mangleof  == "_Z11uint_fast16j");
    static assert(int_fast32.mangleof   == "_Z10int_fast32i");
    static assert(uint_fast32.mangleof  == "_Z11uint_fast32j");
    static assert(int_fast64.mangleof   == "_Z10int_fast64x");
    static assert(uint_fast64.mangleof  == "_Z11uint_fast64y");

    static assert(intptr.mangleof       == "_Z6intptri");
    static assert(uintptr.mangleof      == "_Z7uintptrj");
    static assert(intmax.mangleof       == "_Z6intmaxx");
    static assert(uintmax.mangleof      == "_Z7uintmaxy");
  }
}
else
{
    static assert(0, "unsupported version");
}

