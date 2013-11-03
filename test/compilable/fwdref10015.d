struct S(T) { alias X = int; }

alias Y = s.X;
S!int s;
