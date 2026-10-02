# Authoring notes

`daukle/c` is a managed toolchain. It provisions its own clang, compiles and links, and generates
no file anywhere. It is also the base other C tooling is meant to sit on: `lib/compilers` is
exported so a build tool above it can provision a compiler without writing its own archive table.

## What this cannot do, before anything else

**A provisioned clang is not self-contained on Linux or macOS, so this toolchain has a host
prerequisite.** The archive carries the compiler, its own builtin headers, its own linker and its
own compiler runtime. It does not carry the platform's libc.

| platform | what the host must supply |
| --- | --- |
| `windows/x86_64` | nothing. The archive carries a complete mingw-w64 sysroot |
| `linux/*` | the libc development files, `libc6-dev` on Debian and Ubuntu |
| `macos/*` | the macOS SDK, from the Xcode command line tools |

**So a bare container cannot run this toolchain on Linux**, and a bare container is the shape most
CI starts from. That is the design rather than a defect: the rejected alternative was to provision
musl as well, which makes every binary a different ABI from the host's without saying so. A
prerequisite a user can read is better than an ABI they cannot see.

**The macOS row is reasoned and not measured.** There is no macOS on the machine this was built on,
and a green macOS CI run is not evidence about a bare host, because the runner has the command line
tools installed.

**It compiles C and not C++**, drives clang and not MSVC or gcc, links one executable and not
several, and cannot run what it produced: no verb reaches a file the build just wrote. A project
that wants any of those wants `daukle/cmake`.

## The size of the provision

The clang archive is the largest thing in this org: **485 MB compressed and 1.353 GiB expanded on
Windows**, against 251 MB and 0.679 GiB on Linux. A first run on a cold cache downloads half a
gigabyte, and a user who is surprised by it will suspect a bug.

**This needs a daukle whose unpack ceiling admits it.** The ceiling was 1 GiB and refused the
Windows archive outright; it is 2 GiB from `ce92465` onward. An older daukle fails this toolchain on
Windows with `the archive expands past the 1073741824 byte limit`, which names the limit rather than
the cause.

## The lockstep cost of being a base

`lib/compilers` is exported, and a `requires` entry is a url and a digest of a published artifact.
**So every release of this repository that changes `lib/compilers` requires a new release of every
plugin that pins it** before that plugin can adopt it. There is no range and no floating pin, by
design: a pin that is not exact pins nothing.

A dependent gets the module and **not** this toolchain. Acquiring a dependency does not run its
entry chunk, so a plugin requiring `c:lib/compilers` gets the table and no `c:` task. The layering
is of knowledge, not of capability, and a project that wants both declares both plugins.

## The modelled surface

```toml
[toolchains.c]
version = "21"
sources = ["src/main.c", "src/util.c"]
output  = "hello"
std     = "c17"
defines = ["NDEBUG"]
includeDirs = ["include"]
compileArgs = ["-O2"]
linkArgs    = ["-lm"]
```

`version` is an exact major and **is required**. `java` defaults its JDK version and this does not,
deliberately: widening a key later is compatible and narrowing one is not, so the default is the
change to make when somebody wants it rather than before.

`sources` is an explicit list and cannot name a directory. The verb vocabulary has no way to list
one, so `sources = ["src"]` is a key nobody could implement and it is not offered.

`output` is a name and not a path, because a path writes a generated file at a location daukle does
not own. **Windows gets `.exe` appended**, since clang adds none when `-o` is given and a name the
host cannot execute is a trap.

**Every key is validated in `generate`**, so a manifest that would fail at task time fails at
`daukle check` instead, and a key this plugin does not know is refused rather than ignored.

## Objects are flat

`clang -c -o objects/main.o` does not create `objects/`, and no verb does either, so the objects are
written flat into the task's working directory with their separators folded:

```
src/main.c      ->  src_main.o
src/sub/util.c  ->  src_sub_util.o
```

The fold is not injective, so `src/a.c` and `src_a.c` would collide. That is refused at validation
time rather than silently overwritten. **A build tool above this one gets an object directory
because it brought a build system to make one**; a toolchain driving the compiler directly gets what
the verbs permit.

## The per-host flag table

| host | flags emitted at link |
| --- | --- |
| linux | `-fuse-ld=lld --rtlib=compiler-rt` |
| windows | none |
| macos | none, provisionally |

The Linux pair is what removes the dependency on an installed gcc and binutils, measured in both
directions. The flags are link-time, so `-c` never sees them and never warns that they went unused.
It is a table rather than a conditional so that **the row that is wrong is visible as a row**: the
two measured hosts agree today by coincidence of what clang defaults to, and a coincidence written
as a shared code path is what nobody re-checks when a third row is added.

## A failed compile keeps clang's own words

The compile runs with `check = false` and captures, so a non-zero exit raises with clang's output
**plus** a sentence naming the host prerequisite, and only when the output names a header the
platform's libc supplies. It appends and never substitutes: a rule that rewrote every failing
compile into "install libc6-dev" would be wrong for every genuine syntax error.

The headers clang ships itself (`stddef.h`, `stdarg.h`, `limits.h` and the rest of the builtin set)
are deliberately not in that list. One of those going missing says the provisioned tree is
incomplete and says nothing about the host.

## Conventions this repository is held to

**An optional key with the wrong type raises here.** Every key this toolchain models is validated,
including the optional ones, because a `compileArgs = "-O2"` that is silently ignored builds the
wrong thing. `daukle/c` answered this differently when it was a dependency writer and tolerated a
non-string `sha256`; a toolchain that drives a compiler has no equivalent tolerance to offer.

**Every error carries a `plugin.lua:<line>:` prefix** unless it is raised with level 0. A test
asserting on a message must assert on a clause, never on a token that could also appear in the file
path the message echoes.

**`.gitattributes` pins `* -text`**, and it is load bearing rather than tidy: daukle writes LF on
every platform, so a checkout under `core.autocrlf=true` rewrites the fixtures and the byte-exact
cases fail on Windows for a reason that has nothing to do with the plugin.

**`test/run.sh` is committed `100755`.** A file's git mode is part of its behaviour, and six of
seven plugin repositories in this org have already shipped it wrong.

## Tests

`test/run.sh` runs every directory under `test/cases/` and `examples/` against a real daukle,
because this plugin's output is a real compiler's and a stub of `daukle.exec` would be testing the
stub.

| a case carrying | asserts |
| --- | --- |
| `expect-error.txt` | `daukle sync` fails and the message carries every non-empty line |
| `expected/` | `daukle sync` twice, matching every file byte for byte after both |
| `task.txt` + `produces.txt` | the task succeeds and writes every listed file non-empty |
| `runs.txt` + `expect-output.txt` | the produced executable runs and prints every clause |
| `task.txt` + `expect-task-error.txt` | the task fails carrying every clause |
| `expect-task-absent.txt` | and carries none of these |

`expect-task-absent.txt` is what stops a plugin that appends its host-prerequisite sentence to every
failure from passing every other case.

**A case carrying `needs-clang` provisions a real compiler** and is skipped unless `DAUKLE_C_E2E=1`.
CI sets it on every runner, because the per-platform archives and the flag table above are exercised
by nothing else.

```sh
DAUKLE=/path/to/daukle DAUKLE_C_E2E=1 sh test/run.sh
```

With no `DAUKLE`, the runner looks for a build under `.daukle/`, which is where CI checks
`daukle/daukle` out.

## The release artifact

This plugin is multi-file, so its artifact is a tar and not a bare `plugin.lua`. Two traps came out
of the first releases in this org: the tag is `1.0.0` and **not** `v1.0.0`, and GNU tar reads a
Windows drive letter as a remote host, so the path must be written `/c/...`.

## Provenance

The `FetchContent` writer this repository used to hold moved to `daukle/cmake`, where `1.0.1` ships
it as `deps.lua`. It had to move: core refuses a chunk holding `exec` or `provision` to declare
`daukle.language` at all, so the commit that makes this plugin provision a compiler is the commit
that makes its own `daukle.language` illegal. Its seven test cases went with it and run there as
`deps-*`.
