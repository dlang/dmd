struct Id { ushort value; }
enum Id x = Id(5);
struct S(ushort A) {}
alias CannotCreateFromValue = S!(x.value);
