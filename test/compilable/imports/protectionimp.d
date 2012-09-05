private
{
  class privC {}
  struct privS {}
  interface privI {}
  union privU {}
  enum privE { foo }
  void privF() {}
  mixin template privMT() {}

  class privTC(T) {}
  struct privTS(T) {}
  interface privTI(T) {}
  union privTU(T) {}
  void privTF(T)() {}
}

void publF(T)() {}
void publFA(alias A)() {}
private alias privC privA;

public mixin template publMT() {}
