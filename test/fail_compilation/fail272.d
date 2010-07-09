template Ins(alias x) { const Ins = Ins!(Ins); }
alias Ins!(Ins) x;
