# Authoring notes

`plugin.lua` is the whole plugin. It is published as a release asset and acquired by a `[plugins]`
table entry naming `daukle/c@<range>`.

## What this plugin owns

The text between `# daukle:begin` and `# daukle:end` in a CMake file, and nothing else. It writes
one `FetchContent_Declare` and one `FetchContent_MakeAvailable` per resolved module, then a single
`target_link_libraries` line naming the consumer's configuration as the target. A module block
needs `package` and `url`; `sha256` is optional and becomes `URL_HASH SHA256=` when present.

A target file carrying no region is an error, not a no-op: silently doing nothing to a file the
manifest named is the failure mode this refuses.

## Conventions this repository is held to

These are set here because they are cheap to set at publication and expensive to change
afterwards. They apply to all five extracted plugins.

**An optional key with the wrong type.** Whether it raises is a per-plugin decision, not a rule:
`daukle/github` raises on a non-string `asset` or `tag`, `daukle/c` does not raise on its optional
`sha256`, and both are faithful to the C they replaced. Each repository states its own answer
rather than leaving the reader to infer one.

**Every error carries a `plugin.lua:<line>:` prefix.** Lua's `error()` adds it and the C this
replaced never had it. A test asserting on a message must assert on a clause, never on a token that
could also appear in the file path the message echoes.

## Tests

`test/run.sh` runs every directory under `test/cases/` against a real daukle, because this
plugin's output is a host verb's formatting and a stub of that verb would be testing the stub.

- a case with `expected/` must sync cleanly and match every file in it, byte for byte
- a case with `expect-error.txt` must fail with a message carrying that clause
- every success case is synced **twice** and must match after both, so applying twice equals
  applying once for every case rather than only the one that remembered to say so
- a case whose `expected/` is empty is a failure, not a pass

```sh
DAUKLE=/path/to/daukle sh test/run.sh
```

With no `DAUKLE`, the runner looks for a build under `.daukle/`, which is where CI checks
`daukle/daukle` out.

`.gitattributes` pins `* -text`, and it is load bearing rather than tidy. daukle writes LF on every
platform, so a checkout under `core.autocrlf=true` rewrites the fixtures and the byte-exact cases
fail on Windows for a reason that has nothing to do with the plugin. Measured on Windows, not
assumed: removing the file and re-checking out reproduces the failures.

## Provenance

The cases are the assertions of `test/test_lang_c.c`, deleted from `daukle/daukle` when the
built-in c language became this plugin:

```sh
git -C /path/to/daukle show 262ed15^:test/test_lang_c.c
```

All three byte-exact outputs were compared against the C's literal expected strings with `cmp`,
not by eye, and are identical.
