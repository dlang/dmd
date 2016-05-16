import imports.test15925;

public class Foo
{
    mixin AddImports;

    // Alias from imports.test15925thread which is imported in AddImports
    ThreadAlias fun2;
    // Type from imports.test15925thread which is imported in AddImports
    Thread th2;
}
