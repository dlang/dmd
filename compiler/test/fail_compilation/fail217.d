/*
TEST_OUTPUT:
---
fail_compilation/fail217.d(26): Error: mutable constructor `fail217.Message.this` cannot construct a `immutable` object
    auto m2 = new immutable(Message)(2);
              ^
fail_compilation/fail217.d(17):        Consider adding `const` or `inout` here
    this( int notifier_object )
    ^
---
*/

class Message
  {
    public int notifier;

    this( int notifier_object )
      {
        notifier = notifier_object;
      }
  }

void
main()
  {
    auto m2 = new immutable(Message)(2);
    m2.notifier = 3;
  }
