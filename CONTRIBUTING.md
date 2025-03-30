# Contributing to DMD, the D programming language reference compiler

First off, thanks for your interest in contributing!

For video guides, you can watch [D Contributor Tutorials on YouTube](https://www.youtube.com/playlist?list=PLIldXzSkPUXXSkM5NjBAGNIdkd4Q2Zf0R).

## Reporting bugs

Please search [the issue list](https://github.com/dlang/dmd/issues) before opening a new issue, to see if it's already reported.

For questions about a specific behavior, the [D.Learn](https://forum.dlang.org/group/learn) group is a good place to ask for clarification before reporting an issue.

When creating a new issue, include:
- the version of DMD being used (which can be found by running `dmd --version`).
- A test case:
  - Make it a [short, self-contained, and compilable example](http://sscce.org/).
  - Avoid dependencies on foreign code (e.g. dub packages).
  - Avoid any imports from phobos / druntime if possible.
Minimize the test case using the [DustMite tool](https://github.com/CyberShadow/DustMite/wiki).
DustMite is also available from our [tools](https://github.com/dlang/tools) repository and is distributed with DMD.

### Regressions

When finding a [regression](https://en.wikipedia.org/wiki/Software_regression), please label the issue as such by prefixing the issue title with `[REG 2.XXX.Y]`where `2.XXX.Y` is the first broken version whenever possible.

To help track down the point where regressions were introduced, use the excellent [Digger](https://github.com/CyberShadow/digger) tool.
Digger will automatically bisect the history and identify the Pull Request that introduced the problem.

### Changelog

Changes that don't close an issue, such as new features, or enhancement on existing features, should come with their own changelog entry. Changelog entries should be written for everyday users, not compiler contributors.
Additionally, for larger changes, you may want to add a specialized, detailed entry even if it closes an issue.
See [changelog/README.md](changelog/README.md) for details on how to add a changelog entry.
Note that after a version has entered the release window (there is a beta / the change is in stable), changes should be made directly [in the dlang.org repository](https://github.com/dlang/dlang.org/tree/master/changelog).

## Solving bugs / Submitting pull requests

### Setting up a development environment
Fork [dmd](https://github.com/dlang/dmd/fork) and [phobos](https://github.com/dlang/phobos/fork), and clone them.

```console
git clone git@github.com:your-github-username/dmd.git
git clone git@github.com:your-github-username/phobos.git
```

To be able to pull in updates after the fork is created, add the upstream repositories as a remote.

```console
cd dmd
git remote add upstream git@github.com:dlang/dmd.git
cd ../phobos
git remote add upstream git@github.com:dlang/phobos.git
```

You can try building DMD by following the [instructions in the src folder](https://github.com/dlang/dmd/tree/master/compiler/src).

### Finding bugs to work on

You probably already have bugs that you want to see fixed, but if you need some easier bug fixes to start with, you can look for bugs with the [trivial](https://github.com/dlang/dmd/labels/Severity%3Atrivial) label.

Improving error messages (Label: [Diagnostic Messages](https://github.com/dlang/dmd/labels/Diagnostic%20Messages)) is also a great area to start.

If you have a bug that isn't in the issue list yet, please file it.

### Finding relevant code

When you're not familiar yet with the code base, it can be hard to find where to make the appropriate changes.

- Check the (DMD Source guide)[https://github.com/dlang/dmd/blob/master/compiler/src/dmd/README.md] to get an overview of the compiler's source structure.

- Browse [Existing Pull Requests](https://github.com/dlang/dmd/pulls?q=is%3Apr) solving similar issues to see what files need to be updated for a certain kind of fix.

- Searching for related error messages is also often helpful. For example: if you want to know where to find code that does implicit conversion, search "cannot implicitly convert expression".

### Creating the fix

Check out the `master` or `stable` branch, and pull in the latest changes.
If you just forked the repository, you're probably already up to date.
If it's been a while and you don't update, you might get merge conflicts and spurious test suite failures.

```
git checkout stable
git pull --ff-only upstream stable
```

- Make sure to target the right branch.
Regressions and bug fixes go to stable, new features go to master.
See also: [our release process](https://wiki.dlang.org/DIP75).

Create a new branch, and commit your code changes on there.
```
git checkout -b fix-bug
```



- When fixing a Bugzilla issue, use the title: 'Fix bugzilla issue XXXXX - Issue title'.  This is recognized by both Bugzilla and our GitHub bot (dlang-bot),
  and will automatically link the issue and the pull request together (by providing a link to the issue in Github, and automatically closing bugs when pull requests are merged).

### General guidelines

- Document the 'why' (the change is necessary and was done this way) rather than the 'how'.

- Ensure newly introduced functions / variables are documented and that updates to existing ones are reflected in the documentation.

- Confine a PR to addressing one issue, unless multiple issues are different aspects of the same bug.


- If the pull request affects the language specifications in any way (i.e. changing the grammar, deprecating a feature, or adding a new one),
  a pull request to [the specification in the dlang.org repository](https://github.com/dlang/dlang.org) should be submitted in parallel.

- Follow the usual git good practice:
  - [Provide descriptive commit messages](https://chris.beams.io/posts/git-commit/)
  - Avoid changes not relevant to the issue (i.e. style issues)
  - Separate commit for separate concerns
  - Keep pull requests focused on one single topic or bug.  For example, if the fix requires a refactoring, then submit the refactoring as a separate pull request.

## Refactoring

The purpose of refactoring is to make the code easier to understand and extend. It is not to change the behavior of the
program, add enhancements, or fix bugs.

- Refactorings must come with a rationale as to why it makes the code better.

- Large refactorings should be done in incremental steps that are easy to review.

- When a refactoring is broken down into multiple PRs, it is acceptable to provide a rationale in the first PR and link to it in subsequent PR.

- Pull requests that do non-trivial refactorings should not include other changes, such as new feature or bug fix.
   While submitting multiple dependent pull requests can be done to help the reviewers judge of the need for a refactoring, any refactoring will be assessed on its own merit.

## Refactoring the DMD AST

This guide is tailored for contributors who are interested in assisting with a task crucial to the evolution of the D programming language compiler (DMD): the refactoring of AST (Abstract Syntax Tree) node definitions. This initiative aims to reduce the complex dependencies of AST nodes on semantic analysis functions, a vital step towards making DMD more modular and library-friendly.

### The Task at Hand

In the DMD compiler codebase, AST nodes are defined as classes within various files. The ideal structure for these nodes is to have minimal fields and methods focused solely on field queries. However, the current state of the DMD frontend deviates from this ideal. AST nodes are laden with numerous methods that either perform or are dependent on semantic analysis. Furthermore, many AST node files contain free functions related to semantic analysis. Our objective is to decouple AST nodes from these functions, both directly and indirectly.

### How You Can Help

1. **Choose an AST Node File**: Start by selecting a file from [this list of AST node definition files](https://github.com/orgs/dlang/projects/41).
2. **Examine Imports**: Open your chosen file and scrutinize the top-level imports.
3. **Isolate Semantic Imports**: Temporarily comment out one of the imports that includes semantic routines, particularly those ending in `sem` (e.g., `dsymbolsem`, `expressionsem`, etc.).
4. **Build and Identify Dependencies**: Compile DMD and observe any unresolved symbols that emerge.
5. **Relocate Functions**: Shift the functions reliant on the unresolved symbols to the semantic file where the import was commented out.
6. **Move and Test a Function**: Select a function for relocation and ensure it functions correctly in its new location.
7. **Submit a Pull Request**: Once you're satisfied with the changes, create a PR.
8. **Celebrate Your Contribution**: Take pride in being a part of this significant compiler development effort!

An illustrative example of these steps is shown in [this pull request](https://github.com/dlang/dmd/pull/15755).

Please note that additional steps such as updating C++ headers may be required in certain cases. Be prepared for further requests during the PR review process.

### Addressing More Complex Scenarios

Sometimes, more intricate solutions are required. For instance, if an overridden method in an AST node calls a semantic function, it can't be simply relocated. In these cases, using a visitor to collate all overrides, along with the original method, into the appropriate semantic file is the way forward. A notable instance of this approach is detailed in [this pull request](https://github.com/dlang/dmd/pull/15782).

Other complex scenarios may arise, especially when dealing with AST nodes that interact with the backend. This guide is intended to jumpstart your contributions. As you delve deeper, you'll encounter and learn to navigate these complexities. Remember, Razvan Nitu (@RazvanN7) is available to assist at every stage, so don't hesitate to reach out for guidance.


## DMD Best Practices

Here is a shortlist of stylistic issues the core team will expect in
pull requests. Much of the source code does not follow these, but
we expect new code to, and PRs retrofitting the existing code to
follow it is welcome.

1. Use attributes `const`/`nothrow`/`pure`/`scope`/`@safe`/`private`/etc.
Successfully using `pure` functions is regarded with particular favor.

2. Use correct Ddoc function comment blocks. Do not use Ddoc comments for
overrides unless the overriding function does something different (as far as
the caller is concerned) than the overridden function. Ddoc comment blocks
are often overkill for nested functions and function literals; use ordinary
comments for those. Follow the [D Style](https://dlang.org/dstyle.html#phobos_documentation)
for comment blocks.

3. Do not use `strlen`/`strcmp` and their like. Use D arrays instead.
If slicing from a `char*` is required then use `dmd.utils.toDString`
or the member function `.toString` that is implemented in many classes.

4. Use `ref`/`out` parameters instead of raw pointers.

5. Use nested functions to get rid of rats' nests of goto's.

6. Look for duplicative code and factor out into functions.

7. Declare local variables as `const` as much as possible.

8. Use Single Assignment for local variables:
```
T t = x;
...
t = y;
...
```
becomes:
```
T tx = x;
...
T ty = y;
...
```

9. "Shrinkwrap" the scope of local variables as tightly as possible
around their uses.

10. Similar to (8), use distinct variable names for non-overlapping uses.

11. Avoid the use of mutable globals as much as practical. Consider passing them
in as parameters.

12. Avoid the use of default parameters. Spell them out.

13. Minimize the use of overloading.

14. Avoid clever code. Anybody can write clever code. It takes a genius to write
simple code.

15. Try to reduce cyclomatic complexity, i.e. think about how to make the code work
without control flow statements.

16. Try not to mix functions that "answer a question" with functions that
"mutate the data".
This was done successfully in src/dmd/escape.d, it wasn't easy, but
it was well worth it.

17. Try to eliminate reliance on `global.errors`, use `dmd.errorsink: ErrorSink` instead.

18. For aggregates that expose public access to fields, think hard about why this is
necessary and if it can be done better. Merely replacing them with read/write properties
accomplishes nothing. The more of its internal details can be made private, the better.

19. Try to use function prefixes:

*` do` for performing some action

These functions should not be mutating the data nor issuing error messages.
Make them `const` and `pure` if practical.

* `is` is the parameter in a certain category?
* `has` does the parameter have a certain feature?
* `can` for can I do X with the parameter?
* `needs` for things necessary

20. The function return value variable should be named `result`.

21. The more constrained the scope of a name is, the shorter it should be.

22. Public declarations in modules should be "above the fold", i.e. first in the file, thus making the API of the module
easily visible when opening the file. Private declarations should follow afterwards.

23. Identifiers implying a boolean value should be framed as positives. For example,
`doUnittests` is preferred over `noUnittests`. Never want to see double negatives such
as `if (!noUnittests)`.

24. Identifier Case

* types should start with a capital letter
* variables and functions should start with a lower case letter
* module names should be all lower case (for maximal compatibility with case insensitive file systems)

## The following will not be viewed with favor:

1. Shuffling all the code about

2. As a general rule, any improvement that is implemented by using sed scripts
across the source tree is likely to be disruptive and unlikely to provide
significant improvement.

3. Reformatting into your personal style. Please stick with the existing style.
Use the [D Style](https://dlang.org/dstyle.html#phobos_documentation) for new code.

As always, treating the above as a sacred writ is a huge mistake. Use
your best judgment on a case-by-case basis. Blindly doing things just
adds more technical debt.


## dmd-internals mailing list

For questions and discussions related to DMD development, a [mailing list](https://forum.dlang.org/group/dmd) is available.

## Copyright

All significant contributors to DMD source code, via GitHub, Bugzilla, email,
wiki, the D forums, etc., please assign copyright to those
DMD source code changes to the D Language Foundation. Please send
an email to walter@digitalmars.com with the statement:

> I hereby assign copyright in my contributions to DMD to the D Language Foundation

and include your name and date.
