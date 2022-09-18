/+
ARG_SETS: -version=A
ARG_SETS: -version=B
ARG_SETS: -version=C
ARG_SETS: -version=D
ARG_SETS: -version=E
+/

extern(C):

version (A) int main() { return 0; }

else version (B) int main(const int, const(char*)*) { return 0; }

else version (C) void main(const int, const char**, const char**) {}

else:

enum Length : int;
enum Char : char;
enum CharPtr : char*;
enum CharPtrPtr : char**;

version (D) void main(const Length, const Char**) {}

else version (E) void main(const Length, const CharPtr*, const CharPtrPtr) {}
