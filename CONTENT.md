## What this plugin is

A `daukle.toolchain` named `c`, and a **base** rather than a build system. It provisions a C
compiler, exposes its compiler registry to other plugins, compiles C and links one executable. It
generates no build file at all, because there is no build system to generate one for.

**It drives a compiler and not a particular one.** `plugin.lua` names no compiler anywhere:
everything compiler-specific lives in `lib/compilers.lua`'s registry, so adding a compiler is a row
there and no code anywhere. It ships two, clang and gcc, and a manifest picks one with `compiler`.

It is more often required by another plugin than declared directly. `daukle/cmake` sits above it and
requires it under the alias `cc`, a one-letter alias being impossible because a letter before a
colon is a Windows drive letter.

## Being a base has a release cost, and it is exact

`lib/compilers` is exported, and a `requires` entry is a url and a digest of a published artifact.
**So every release of this repository that changes that registry needs a new release of every plugin
pinning it** before those plugins can adopt it. There is no range and no floating pin, by design: a
pin that is not exact pins nothing.

`compiler` was added as an optional key for exactly this reason: `daukle/cmake@1.0.0` calls
`for_host` without it, so the key is an addition and never a change, and cmake adopts a compiler
selection on its own schedule rather than at this repository's next release.

A dependent gets the module and **not** this toolchain. Acquiring a dependency does not run its
entry chunk, so a plugin requiring `c:lib/compilers` gets the registry and no `c:` task. The layering
is of knowledge rather than of capability, and a project wanting both declares both plugins.

## It is the largest provision in the organization

The clang archive is **485 MB compressed and 1.353 GiB expanded on Windows**, against 251 MB and
0.679 GiB on Linux. A first run on a cold cache downloads half a gigabyte, which is worth knowing
before you suspect a bug. The gcc archive is smaller, 211 MB on Windows and 172 MB on Linux.

**It needs a daukle whose unpack ceiling admits the clang archive.** That ceiling was 1 GiB and
refused the Windows one outright. An older daukle fails here with `the archive expands past the
1073741824 byte limit`, a message that names the limit rather than the cause.

## What it deliberately does not do

It compiles C and not C++, links one executable and not several, and cannot run what it produced.
Anything needing a build file, more than one target, or a verb that reaches a file the build just
wrote wants `daukle/cmake`.

**MSVC is out of scope rather than deferred.** It ships inside a Visual Studio installation rather
than as an archive with a digest, and provisioning the tool and pinning it by sha256 is this
plugin's whole contract. A toolchain that uses whatever compiler the host already has is a different
shape, and that shape is `daukle/cmake`'s.

## Where the rest is

The host prerequisite that shaped this plugin, the keys, the compiler registry and the per-compiler
flag tables are in this repository's `wiki/index.md`, rendered at
<https://daukle.github.io/guide/>. `AUTHORING.md` opens with what this toolchain cannot do and is
the measured detail for anyone changing it.
