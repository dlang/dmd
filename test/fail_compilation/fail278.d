template Id(xs...) { const Id = xs[0]; }
template Foo() { mixin Id!(NONEXISTENT!()); }
template Bar(alias F) { const int Bar = F!(); }
alias Bar!(Foo) x;
