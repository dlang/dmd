// REQUIRED_ARGS: -O

class Bug8525
{
    int[] elements;

    final int bar()
    {
        return elements[0];
    }
}
