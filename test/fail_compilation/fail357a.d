void fail357()
{
    enum foo { A, }

    // symbol collision of enum and function
    import imports.fail357a : foo;
}
