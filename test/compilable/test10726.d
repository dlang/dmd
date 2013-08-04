public struct CirBuff(T) {                                                // 01
  private T[] data;                                                       // 02
  private size_t head = 0;                                                // 03
  private size_t size = 0;                                                // 04
  public size_t length() const {return size;}                             // 05
  public bool opEquals(CirBuff!T d) @trusted {                            // 06
    if(length != d.length) return false;                                  // 07
    for(size_t i=0; i!=size; ++i)                                         // 08
      if(this.data[(this.head+i)%this.data.length] !=                     // 09
     d.data[(d.head + i) % d.data.length]) return false;                  // 10
    return true;                                                          // 11
  }                                                                       // 12
}                                                                         // 13
class Once {                                                              // 14
  Foo!Bar _bar;                                                           // 15
}                                                                         // 16
class Bar {                                                               // 17
  static Once _once;                                                      // 18
  mixin(sync!(Once, "_once"));                                            // 19
}                                                                         // 20
class Foo (T=int) {                                                       // 21
  CirBuff!T _buff;                                                        // 22
}                                                                         // 23
template sync(T, string U="this", size_t ITER=0) {                        // 24
  static if(ITER == __traits(derivedMembers, T).length) enum sync = "";   // 25
  else {                                                                  // 26
    enum string mem = __traits(derivedMembers, T)[ITER];                  // 27
    enum string sync =                                                    // 28
      "static if(! __traits(isVirtualMethod, " ~ U ~ "." ~ mem ~ ")) { }" // 29
      ~ sync!(T, U, ITER+1);                                              // 30
  }                                                                       // 31
}                                                                         // 32
