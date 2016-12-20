How to add a new changelog entry to the pending changelog?
==========================================================

This will get copied to dlang.org and cleared when master gets
merged into stable prior to a new release.

```
My fancy new feature X

A long description of the new feature.
-------
import std.range;
import std.algorithm.comparison;

assert([1, 2, 3, 4, 5].padLeft(0, 7).equal([0, 0, 1, 2, 3, 4, 5]));

assert("Hello World!".padRight('!', 15).equal("Hello World!!!!"));
-------
```

The title can't contain links (it's already one).
For more infos, see the [Ddoc spec](https://dlang.org/spec/ddoc.html).

Preview changes
---------------

If you have cloned the [tools](https://github.com/dlang/tools) and [dlang.org](https://github.com/dlang/dlang.org) repo),
you can preview the changelog:

```
../tools/changed.d -o ../dlang.org/changelog/pending.dd && make -C ../dlang.org -f posix.mak html
```

and then open `../dlang.org/web/changelog/pending.html` with your favorite browser.
