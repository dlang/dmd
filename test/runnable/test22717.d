// PERMUTE_ARGS: -version=XopEquals

void main()
{
  // TODO: remove as soon as `git describe` for DMD master yields v2.099+
  static if (__VERSION__ >= 2099)
  {
    static struct S
    {
        int value;

        version (XopEquals)
        {
            bool opEquals(const S rhs) const
            {
                assert(this.value == 42);
                return true;
            }
        }
        else
        {
            bool opEquals(const ref S rhs) const
            {
                assert(this.value == 42);
                return true;
            }
        }
    }

    auto a = S(42);
    auto b = S(24);
    auto ti = typeid(S);
    assert(ti.equals(&a, &b));
  }
}
