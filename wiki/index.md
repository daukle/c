# daukle/c

The C base. It provisions a C compiler and exposes it to other plugins; it generates no build file at
all, because there is no build system to generate for.

## Declaring it

```toml
[plugins]
c = "daukle/c@^1"
```

It is more often **required by another plugin** than declared directly: `daukle/cmake` requires it
under the alias `cc`, and uses its compiler registry.

**The alias is `cc` and not `c`**, because core refuses a one-letter alias: a letter before a colon
is a Windows drive letter, so `daukle.require("c:...")` could never resolve.

## Choosing a compiler

```toml
[toolchains.c]
compiler = "gcc"
version  = "15"
sources  = ["src/main.c"]
output   = "hello"
```

`compiler` is **optional**, and omitting it provisions clang. `version` is the version **of the
selected compiler**, which is why the two keys travel together: `"21"` means clang 21 and `"15"`
means gcc 15. Both are exact majors, because this plugin pins its archives by sha256 and does not
match ranges.

A compiler this plugin has no published archive for is **refused by name**, and the message lists
the ones it has. That is deliberate: the plugin provisions and pins what it drives, so a compiler it
cannot acquire is a compiler it cannot be asked for.

### Host coverage is not the same for both

| host | clang 21 | gcc 15 |
| --- | --- | --- |
| `linux/x86_64`, `linux/aarch64` | yes | yes |
| `windows/x86_64` | yes | yes |
| `macos/x86_64`, `macos/aarch64` | yes | **none published** |
| `windows/aarch64` | none | none |

A host with no archive is refused naming the host rather than guessed at.

## MSVC is out of scope, not missing

`cl.exe` ships inside a Visual Studio installation rather than as an archive with a digest, and
provisioning the tool and pinning it by sha256 is this plugin's whole contract. It is also a
different dialect: `cl.exe` refuses `-Wextra`, while the same clang binary accepts the MSVC spelling
under `--driver-mode=cl`, so a dialect is a property of an invocation and not of a tool identity.

A toolchain that uses whatever compiler the host already has is a different shape. That shape is
`daukle/cmake`'s.

## A provisioned C compiler is not a self-contained toolchain

This is the finding that shaped the plugin, and it is a property of C rather than a defect here.
It is true of both compilers it ships.

**A provisioned compiler needs the host's libc development files** on Linux and macOS, which no
compiler archive contains. So `daukle/c` is the first plugin in this organization with a host
prerequisite, and a bare container is the shape most CI starts from. On Windows nothing is needed:
both archives carry a complete mingw-w64 sysroot.

The rejected alternative was provisioning musl, which turns every binary into a different ABI from
the host's without saying so.

## What it does not do

It is a base, not a build system. Anything that needs a build file wants `daukle/cmake`, which sits
above this one.
