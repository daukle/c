# Authoring notes

`daukle/c` is a managed toolchain. It provisions its own compiler, compiles and links, and generates
no file anywhere. It is also the base other C tooling is meant to sit on: `lib/compilers` is
exported so a build tool above it can provision a compiler without writing its own archive table.

**It drives a COMPILER and not a particular one.** `plugin.lua` names no compiler anywhere, and
`grep -i 'clang\|gcc' plugin.lua` returning nothing is a standing property of this repository rather
than an accident. Everything compiler-specific lives in `lib/compilers.lua`'s registry, so adding a
compiler is a row there and no code anywhere.

## What this cannot do, before anything else

**A provisioned compiler is not self-contained on Linux or macOS, so this toolchain has a host
prerequisite.** The archive carries the compiler, its own builtin headers, its own linker and its
own compiler runtime. It does not carry the platform's libc. Measured 2026-10-07 against both the
clang and the gcc archives, which tell the same story.

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

**It compiles C and not C++**, links one executable and not several, and cannot run what it
produced: no verb reaches a file the build just wrote. A project that wants any of those wants
`daukle/cmake`.

**MSVC is out of scope rather than deferred**, and for two reasons that are both permanent. It ships
inside a Visual Studio installation rather than as an archive with a digest, and this plugin's whole
contract is to provision the tool and pin it by sha256. It is also a different dialect: measured
2026-10-07, `cl.exe` refuses `-Wextra` outright, while the same clang binary accepts the MSVC
spelling under `--driver-mode=cl`. **So a dialect is a property of an invocation, not of a tool
identity**, and a toolchain that uses whatever compiler the host already has is a different shape
altogether. That shape is `daukle/cmake`'s.

## The size of the provision

The clang archive is the largest thing in this org: **485 MB compressed and 1.353 GiB expanded on
Windows**, against 251 MB and 0.679 GiB on Linux. A first run on a cold cache downloads half a
gigabyte, and a user who is surprised by it will suspect a bug. **gcc is smaller**, 211 MB on
Windows and 172 MB on Linux, which is not a reason to prefer it and is the reason the Windows
ceiling below is about clang.

**Every size on this page is decimal MB**, as the publisher reports it. The same assets are 463 and
240 MiB, and a page that mixed the two would read as a measurement that had drifted.

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

## The compiler registry

`lib/compilers.lua` is the only file in this plugin that names a compiler. It is a **list** of
descriptors rather than a map, because the refusal message names the compilers that exist and
`pairs` would order them differently between runs.

A descriptor carries the archive coordinates (`project`, `home`, `releases`, `digests`) and the
three things that turned out to be compiler-specific rather than plugin-wide:

| field | why it is per compiler, measured 2026-10-07 |
| --- | --- |
| `link_flags` | clang's Linux pair is **rejected by gcc**: `--rtlib=compiler-rt` is not a flag it has, and there is no `lld` in its archive to point `-fuse-ld` at. gcc needs none at all, because it bundles its own binutils |
| `missing_header` | the wording of a diagnostic belongs to the compiler that emits it. clang says `'stdio.h' file not found`; gcc says `stdio.h: No such file or directory`, or `no include path in which to search for stdio.h` under `-nostdinc` |
| `prerequisite` | per host, and shared by every compiler today, because both measured archives tell the same story. A compiler whose story differs overrides it on its own descriptor rather than adding a conditional |

**The asset basename is derived from `home` plus the platform**, which is one fact rather than two:
every xpack archive unpacks to a directory named after itself with the platform suffix removed.

**`for_host`'s signature is load bearing.** `daukle/cmake@1.0.0` pins this file and calls
`for_host{ os, arch, version }` with no `compiler`, so the key is an addition and never a change: a
default row that stopped equalling its clang row would break cmake at a release it cannot see
coming. `the-table-answers-every-published-row` asserts the default rows and the named clang rows
byte for byte, which is that obligation written as a test rather than as a sentence.

### Host coverage is per compiler, and is not the same

| host | clang 21 | gcc 15 |
| --- | --- | --- |
| `linux/x86_64`, `linux/aarch64` | yes | yes |
| `windows/x86_64` | yes | yes, with its own mingw-w64 sysroot |
| `macos/x86_64`, `macos/aarch64` | yes | **none published, at any version** |
| `windows/aarch64` | none | none |

A host with no row is refused by name rather than guessed at, which is what makes a missing row a
message a user can act on. **gcc cannot be provisioned on macOS from this publisher**, which is a
constraint on the test matrix rather than a defect.

## The modelled surface

```toml
[toolchains.c]
compiler = "gcc"
version  = "15"
sources  = ["src/main.c", "src/util.c"]
output   = "hello"
std      = "c17"
defines  = ["NDEBUG"]
includeDirs = ["include"]
compileArgs = ["-O2"]
linkArgs    = ["-lm"]
```

`compiler` selects a registry entry and **is optional**: omitting it takes the entry marked
`default`, which is why every manifest written before the key existed keeps meaning what it meant.
The default is a field on a row rather than a literal in `plugin.lua`, so the code asks the registry
for it and still names no compiler.

`version` is an exact major and **is required**. It is the version **of the selected compiler**,
which is why the two keys travel together: `"21"` means clang 21 and `"15"` means gcc 15. `java`
defaults its tool version and this does not, deliberately: widening a key later is compatible and
narrowing one is not, so the default is the change to make when somebody wants it rather than
before.

`sources` is an explicit list and cannot name a directory. The verb vocabulary has no way to list
one, so `sources = ["src"]` is a key nobody could implement and it is not offered.

`output` is a name and not a path, because a path writes a generated file at a location daukle does
not own. **Windows gets `.exe` appended**, since a compiler adds none when `-o` is given and a name
the host cannot execute is a trap.

**Every key is validated in `generate`**, so a manifest that would fail at task time fails at
`daukle check` instead, and a key this plugin does not know is refused rather than ignored.

## Objects are flat

`-c -o objects/main.o` does not create `objects/`, and no verb does either, so the objects are
written flat into the task's working directory with their separators folded:

```
src/main.c      ->  src_main.o
src/sub/util.c  ->  src_sub_util.o
```

The fold is not injective, so `src/a.c` and `src_a.c` would collide. That is refused at validation
time rather than silently overwritten. **A build tool above this one gets an object directory
because it brought a build system to make one**; a toolchain driving the compiler directly gets what
the verbs permit.

## The link flag table is per compiler as well as per host

| host | clang 21 | gcc 15 |
| --- | --- | --- |
| linux | `-fuse-ld=lld --rtlib=compiler-rt` | none |
| windows | none | none |
| macos | none, provisionally | no row, because there is no archive |

**The two columns are not the same flags spelled differently, they are a different need.** clang's
archive bundles `lld` and `compiler-rt` but no binutils, so without the Linux pair its link falls
back to an installed `gcc` and `ld`. gcc's archive bundles its own `ld`, `as` and `ar` and carries no
`lld` at all, so the same pair would refuse: measured 2026-10-07, `--rtlib=compiler-rt` is not a flag
gcc has, and a bare `ubuntu:24.04` with `libc6-dev` compiled, linked and ran with no link flags
whatever.

The flags are link-time, so `-c` never sees them and never warns that they went unused. It is a
table rather than a conditional so that **the row that is wrong is visible as a row**, and the
columns live on the descriptors so that adding a compiler cannot quietly inherit another's flags.

## A failed compile keeps the compiler's own words

The compile runs with `check = false` and captures, so a non-zero exit raises with the compiler's
output **plus** a sentence naming the host prerequisite, and only when the output names a header the
platform's libc supplies. It appends and never substitutes: a rule that rewrote every failing
compile into "install libc6-dev" would be wrong for every genuine syntax error.

**The pattern that recognises a missing header is the compiler's, not the plugin's**, which is why
it is a descriptor field. clang says `'stdio.h' file not found`; gcc says
`stdio.h: No such file or directory`. A plugin carrying only clang's wording would have left every
gcc user without the hint and with no sign that a hint was missing.

The headers a compiler ships itself (`stddef.h`, `stdarg.h`, `limits.h` and the rest of the builtin
set) are deliberately not in that list. One of those going missing says the provisioned tree is
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

**`test/cases.sh` is committed `100755`.** A file's git mode is part of its behaviour, and six of
seven plugin repositories in this org have already shipped it wrong.

## Tests

`test/cases.sh` runs every directory under `test/cases/` against a real daukle, because this
plugin's output is a real compiler's and a stub of `daukle.exec` would be testing the stub.
`examples/` is run separately, by core's one org-wide harness: `.daukle/tools/run-examples.sh`.

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

**A case carrying `needs-tools` provisions a real compiler** and is skipped unless
`DAUKLE_C_E2E=1`. CI sets it on every runner, because the per-platform archives and the flag tables
above are exercised by nothing else.

**A case carrying `only-hosts` names the hosts it can run on**, one per line, in daukle's spelling,
and is skipped elsewhere. It exists because host coverage is per compiler: there is no macOS gcc at
any version, so a case that provisions one can only run where an archive exists. The alternative
would be a case that passes by being refused, which asserts the registry rather than the compile.

```sh
DAUKLE=/path/to/daukle DAUKLE_C_E2E=1 sh test/cases.sh
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
