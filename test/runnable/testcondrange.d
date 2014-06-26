alias Tuple(T...) = T;
void main(string[] args)
{
  foreach(const i; 0..args.length?2:3)
    static assert(__traits(valueRange, i) == Tuple!(0, 2));
}
