class C(T...) {
  void a(T[] o) {
    foreach(p; o) int a = 1;
  }
}

alias C!(int) foo;


