# c-hello-executable

A managed C project. The repository holds `daukle.toml`, `src/` and `include/` and **no build
file**: no `CMakeLists.txt`, no `Makefile`, no configure script. daukle downloads a clang, verifies
it against a digest the plugin pins, and runs it directly.

```console
$ daukle c:link
$ ./build/daukle/c/hello
hello from daukle
```

`daukle c:compile` runs one `clang -c` per source into `build/daukle/c/` and `c:link` depends on it,
so linking compiles first. `daukle tasks` lists the two tasks and their order.

**There is no `c:run`, and the second line above is why that costs nothing.** A toolchain that
links a program does not have to learn how to start one: running it is just a second command, and
asserting on what the program printed is a stronger claim than asserting that its object files
exist.

## What to look at

**This example names a published coordinate, exactly as your project would.** Nothing points at a
working tree, so the directory can be copied anywhere and `daukle sync` works. The suite then runs
it twice, once as committed against the published release and once with this repository's working
tree staged over a copy, so a break in the plugin as it stands reddens this repository rather than
waiting for a release.

**`sources` is an explicit list.** There is no glob and no directory form, because the verb
vocabulary has no way to list a directory. That is a real cost of a toolchain with no build system
under it, and it is stated rather than worked around.

**`output` is a name, not a path.** On Windows the linked file is `hello.exe`; the manifest says
`hello` on every platform and the plugin adds the suffix.

**`includeDirs` is doing work here.** `greet.h` lives in `include/` and not beside `main.c`, so the
`#include "greet.h"` in `src/main.c` only resolves because the plugin passes `-Iinclude`.

**`version = "21"` is an exact major version and is required.** `">=17"` is refused and there is no
default: the plugin ships a table of pinned clang archives with their published digests, and
matching a range would mean a semver implementation in Lua.

## What this example cannot show

**A compile on a bare Linux or macOS host.** The provisioned clang carries its own builtin headers,
linker and compiler runtime, and **not the platform's libc**. On Linux this project needs
`libc6-dev` installed; on macOS it needs the Xcode command line tools. Only Windows is
self-contained, because the archive carries a complete mingw-w64 sysroot. A bare container cannot
build this, which is the honest cost of the design rather than a defect.

**Running what it built.** There is no `c:run`, and it is not an oversight: no verb in daukle
reaches a file the build just wrote. `daukle.tool` names a member of a provisioned root, and the
executable here is neither. The example is checked by the test harness running `build/daukle/c/hello`
itself, which daukle cannot do for you.

**C++.** `clang++` and a `libc++` tree are in the same archive and this toolchain exercises neither.
A C++ surface needs a standard-library decision that has not been taken.

**More than one output.** One link step, one executable. Several targets is what `daukle/cmake` is
for.

**An external dependency.** This toolchain compiles your sources and nothing else. Coordinates for
C libraries are what `daukle/cmake`'s `deps.lua` writer is for, against a `CMakeLists.txt` you own.

## The first run is slow

Roughly 251 MB of clang on Linux and 485 MB on Windows, with no progress reported while it
downloads, expanding to 0.679 GiB and 1.353 GiB respectively. It is cached per digest afterwards and
shared by every project on the machine that pins the same compiler. It is the largest provision in
this org by some margin, and a daukle older than `ce92465` refuses the Windows one outright.

## The one file that is a harness input rather than part of the example

`needs-tools` is the marker that makes this example skip unless `DAUKLE_EXAMPLE_E2E=1` is set, so a
local run does not download half a gigabyte unasked. CI sets it on every runner.

It replaced four sidecars, which is the clearest case in this organization for the `console` block
above: `task.txt`, `produces.txt`, `runs.txt` and `expect-output.txt` all said in a file what the
block now says in the document a reader was already reading. **The two object files `produces.txt`
named are no longer asserted, and that is a deliberate loss**: a linked program that runs and
prints the right line is a stronger claim than two `.o` files existing.

**There is no committed executable here, and nothing is missing.** `c:link` really does build it;
`build/` is gitignored, which is the only reason you cannot see the result in the repository.
