module imports.test15966base;

class Base
{
    private import imports.test15966a;
    // only private imports are restricted atm.
    package(imports) import imports.test15966b;
}
