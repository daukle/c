# daukle/c

The C base. It provisions a clang and exposes it to other plugins; it generates no build file at
all, because there is no build system to generate for.

## Declaring it

```toml
[plugins]
c = "daukle/c@^1"
```

It is more often **required by another plugin** than declared directly: `daukle/cmake` requires it
under the alias `cc`, and uses its compiler table.

**The alias is `cc` and not `c`**, because core refuses a one-letter alias: a letter before a colon
is a Windows drive letter, so `daukle.require("c:...")` could never resolve.

## A provisioned C compiler is not a self-contained toolchain

This is the finding that shaped the plugin, and it is a property of C rather than a defect here.

**A provisioned clang needs the host's libc development files** on Linux and macOS, which no
compiler archive contains. So `daukle/c` is the first plugin in this organization with a host
prerequisite, and a bare container is the shape most CI starts from.

The rejected alternative was provisioning musl, which turns every binary into a different ABI from
the host's without saying so.

## What it does not do

It is a base, not a build system. Anything that needs a build file wants `daukle/cmake`, which sits
above this one.
