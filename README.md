# c

The C language plugin for daukle. It renders resolved modules into a CMake region as FetchContent_Declare and FetchContent_MakeAvailable calls followed by one target_link_libraries line, rewriting only the text between the daukle markers.

## Examples

- [`c-hello-executable`](examples/c-hello-executable): A managed C project.

## What this plugin is

A `daukle.toolchain` named `c`, and a **base** rather than a build system. It provisions a clang,
exposes its compiler table to other plugins, compiles C and links one executable. It generates no
build file at all, because there is no build system to generate one for.

It is more often required by another plugin than declared directly. `daukle/cmake` sits above it and
requires it under the alias `cc`, a one-letter alias being impossible because a letter before a
colon is a Windows drive letter.

## Being a base has a release cost, and it is exact

`lib/compilers` is exported, and a `requires` entry is a url and a digest of a published artifact.
**So every release of this repository that changes that table needs a new release of every plugin
pinning it** before those plugins can adopt it. There is no range and no floating pin, by design: a
pin that is not exact pins nothing.

A dependent gets the module and **not** this toolchain. Acquiring a dependency does not run its
entry chunk, so a plugin requiring `c:lib/compilers` gets the table and no `c:` task. The layering
is of knowledge rather than of capability, and a project wanting both declares both plugins.

## It is the largest provision in the organization

The clang archive is **485 MB compressed and 1.353 GiB expanded on Windows**, against 251 MB and
0.679 GiB on Linux. A first run on a cold cache downloads half a gigabyte, which is worth knowing
before you suspect a bug.

**It needs a daukle whose unpack ceiling admits it.** That ceiling was 1 GiB and refused the Windows
archive outright. An older daukle fails here with `the archive expands past the 1073741824 byte
limit`, a message that names the limit rather than the cause.

## What it deliberately does not do

It compiles C and not C++, drives clang and not MSVC or gcc, links one executable and not several,
and cannot run what it produced. Anything needing a build file, more than one target, or a verb that
reaches a file the build just wrote wants `daukle/cmake`.

## Where the rest is

The host prerequisite that shaped this plugin, the keys and the per-host flag table are in this
repository's `wiki/index.md`, rendered at <https://daukle.github.io/guide/>. `AUTHORING.md` opens
with what this toolchain cannot do and is the measured detail for anyone changing it.

## License

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
