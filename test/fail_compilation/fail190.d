T* f(T...)(T x) {
  return null;
} 
void main() {
  auto x = f(2,3,4);
  *x = *x;
} 

