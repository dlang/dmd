struct Small { uint x; }
struct Large { uint x, y, z; }
Small foo() { return Small(); }
void main() { 
  Large l; Small s; 
  l = cast(Large)foo();
}
