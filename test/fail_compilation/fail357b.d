void fail357()
{
    // symbol collision of enum and function
    import imports.fail357a : foo;

    enum foo { A, }
}
