auto f(string s, alias g)() {
    return true;
}

alias a = f!("a", output => output);
alias b = f!("b", output => true);
