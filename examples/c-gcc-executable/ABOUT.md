# c-gcc-executable

The same project as `c-hello-executable` with **one key added**. `daukle/c` drives a compiler rather
than a particular one, so choosing gcc is a line of manifest and nothing else: same sources, same
`std`, same `includeDirs`, same tasks.

```console
$ daukle c:link
$ ./build/daukle/c/hello
hello from gcc
```

## What to look at

**`compiler = "gcc"` is the whole diff.** `c-hello-executable` omits the key and gets clang, because
the default is a field on a row in the plugin's registry rather than a literal in its code.
`grep -i 'clang\|gcc' plugin.lua` in that repository returns nothing.

**`version = "15"` is gcc's version, not the toolchain's.** The two keys travel together: `"21"`
means clang 21 and `"15"` means gcc 15. Both are exact majors, because the plugin pins its archives
by sha256 and does not match ranges.

**`src/main.c` refuses to compile under the wrong compiler.** It `#error`s if `__clang__` is defined
or if `__GNUC__` is not 15, so this example cannot pass by accident if the key stops being read.
That matters more here than in most examples: a compiler that silently ignored the selection would
still print `hello from gcc`, because the string comes from the source and not from the tool.

**No link flags are passed, and that is a measured difference.** clang's Linux build needs
`-fuse-ld=lld --rtlib=compiler-rt` because its archive carries lld and compiler-rt but no binutils.
gcc's archive bundles its own `ld`, `as` and `ar`, and has no lld at all, so the same pair would be
refused. The plugin carries them per compiler for that reason.

## What this example cannot show

**macOS.** `needs-tools` names `linux` and `windows`, and the harness skips this example anywhere
else. **xpack publishes no macOS gcc at any version** — not an old one, not a different channel — so
there is no archive to pin and the plugin refuses the host by name. This is the first example in the
organization with a host gate, and the gate exists because of this example.

**That gcc is better, or recommended.** It is a second compiler, not a preferred one. The default is
still clang and `c-hello-executable` is still the example to read first.

**MSVC.** Out of scope for this plugin rather than missing: `cl.exe` ships inside a Visual Studio
installation rather than as an archive with a digest, and provisioning the tool and pinning it by
sha256 is the plugin's whole contract. It is also a different dialect.

**A bare Linux host.** As with the clang example, the provisioned compiler carries its own builtin
headers, linker and runtime and **not the platform's libc**, so Linux needs `libc6-dev` installed.
Windows is self-contained, because this archive carries a complete mingw-w64 sysroot of its own.

## The first run is slow

Roughly 172 MB of gcc on Linux and 211 MB on Windows. It is cached per digest afterwards and shared
by every project on the machine that pins the same compiler. That is smaller than the clang archive,
which is 251 MB and 485 MB, and is not a reason to prefer it.
