// 7862

template B(T) {
  mixin(
    {
      foreach (name; __traits(derivedMembers, T)) {}
      return "struct B {}";
    }()
  );
}

struct A {
  pragma(msg, "A: ", __traits(compiles, B!A));
  B!A c;
  static if (nonExistent!()) {}
}

auto d = A.init.c;

