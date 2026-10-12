--[[ @implNote the registry is the ONLY place in this plugin that names a
     compiler. plugin.lua asks for a descriptor and reads fields off it, so
     adding a compiler is a row here and no code anywhere, and a compiler the
     plugin cannot provision is a compiler it cannot be asked for.

     It is a LIST rather than a map because the refusal message names the
     compilers that exist, and `pairs` would order them differently between
     runs. ]]

-- daukle names the host; xpack names the file. The two disagree on every
-- field, so the tables are keyed on daukle's spelling and translated on the
-- way out.
local ASSET_OS = { linux = "linux", macos = "darwin", windows = "win32" }
local ASSET_ARCH = { x86_64 = "x64", aarch64 = "arm64" }
local ASSET_EXT = { linux = "tar.gz", macos = "tar.gz", windows = "zip" }

local COMPILERS = {
  {
    id = "clang",
    default = true,
    binary = "clang",
    project = "clang-xpack",
    -- One string where java and cmake both need a per-platform table: xpack
    -- does not bundle on macOS, so there is no Contents/Home to fold in and
    -- every archive's first member is xpack-clang-<version>/ with bin/
    -- directly inside.
    home = "xpack-clang-%s",
    releases = { ["21"] = "21.1.8-1" },
    -- Transcribed from the .sha xpack publishes beside each asset. Never
    -- computed from a file on disk: core.autocrlf rewrites line endings and a
    -- digest taken from a working tree stops matching the published bytes.
    digests = {
      ["21"] = {
        ["linux/x86_64"]   = "0db58136aedb58b9af8c605a1b1570defbe06618f82bff60d24d3327f81d8321",
        ["linux/aarch64"]  = "be1eae2706c049ff9d1c5816e58bb5557d75810c9762cb929208472f7914617e",
        ["macos/x86_64"]   = "eab22258684105f5c32bb29772e2b17bc2ec4eac49b3c4d1775e45b3d1baf385",
        ["macos/aarch64"]  = "562270fc3029fbec56cadde80223efe2ea33e9fde46954582447afb4832310ea",
        ["windows/x86_64"] = "b23d38e2c1c539182919e147e7158fd8b4e8bdd9e6ddc5dfe06f6488c6d9d516",
      },
      -- xpack publishes no windows/aarch64 clang, so there is no entry for it
      -- and for_host raises naming the host. A table that is right by
      -- coincidence is one nobody checks when a row is added.
    },
    --[[ A table rather than a conditional, so the row that is wrong is visible
         as a row. Linux needs the pair because this archive bundles lld and
         compiler-rt but no binutils, so without them the link depends on an
         installed gcc; Windows and macOS were measured to need nothing. The
         flags are link-time, so -c never sees them and never warns that they
         went unused. ]]
    link_flags = {
      linux = { "-fuse-ld=lld", "--rtlib=compiler-rt" },
      macos = {},
      windows = {},
    },
    -- The wording of a diagnostic belongs to the compiler that emits it, not
    -- to this plugin: measured 2026-10-07, gcc reports the same condition as
    -- "<header>: No such file or directory".
    missing_header = { "'([^']+)' file not found" },
  },
  {
    id = "gcc",
    binary = "gcc",
    project = "gcc-xpack",
    home = "xpack-gcc-%s",
    releases = { ["15"] = "15.2.0-1" },
    digests = {
      ["15"] = {
        ["linux/x86_64"]   = "f6dcc3815299a23b2b4372223c4ca5f1b5a0543ed097d57eb67e0753b7c484e0",
        ["linux/aarch64"]  = "8d6e78782994ffdfdabbc8f485bc98d817d17b1f9c12e4163c7d6c50d4a16912",
        ["windows/x86_64"] = "be18e491c8da564f0b923d29ca0ffc8927f4a51c883d5827a8eb9c3d5386c5b0",
      },
      -- v15.2.0-1 publishes three archives and no more: there is no macOS gcc
      -- at ANY version from this publisher and no windows/aarch64, so a
      -- project asking for either is refused naming its host.
    },
    --[[ Empty on every host, measured 2026-10-07 against both real archives
         rather than copied from clang's row: this one bundles its own binutils
         (ld, as, ar) and carries no lld at all, so clang's -fuse-ld=lld would
         refuse and --rtlib=compiler-rt is not a flag gcc has. A bare
         ubuntu:24.04 with libc6-dev compiled, linked and ran with no link
         flags whatever. There is no macos row because there is no archive. ]]
    link_flags = {
      linux = {},
      windows = {},
    },
    -- Two forms, measured 2026-10-07: the first is what a bare host produces,
    -- the second is what -nostdinc produces, and neither resembles clang's.
    missing_header = {
      "fatal error: ([^:]+): No such file or directory",
      "no include path in which to search for ([%w_%-%.]+)",
    },
  },
}

--[[ Per host and shared by every compiler, because it is a fact about the
     PLATFORM: both archives measured 2026-10-07 carry their own builtin
     headers, linker and runtime and neither carries a libc, and on Windows
     both carry a complete mingw-w64 sysroot. A compiler whose story differs
     gets its own row on its descriptor rather than a conditional here. ]]
local PREREQUISITE = {
  linux = 'a provisioned %s carries its own builtin headers, linker and runtime, but not the'
          .. ' platform libc: install the libc development files, which are libc6-dev on Debian'
          .. ' and Ubuntu',
  macos = 'a provisioned %s carries its own builtin headers, linker and runtime, but not the'
          .. ' macOS SDK: install the Xcode command line tools with "xcode-select --install"',
  windows = 'this %s carries its own mingw-w64 sysroot, so a missing standard header means the'
            .. ' provisioned tree is incomplete rather than that the host is',
}

local BY_ID = {}
local NAMES = {}
for index = 1, #COMPILERS do
  BY_ID[COMPILERS[index].id] = COMPILERS[index]
  NAMES[index] = COMPILERS[index].id
end

local function known_names()
  return table.concat(NAMES, ", ")
end

local function default_descriptor()
  for index = 1, #COMPILERS do
    if COMPILERS[index].default then return COMPILERS[index] end
  end
  error("the compiler registry names no default, so an omitted \"compiler\" selects nothing", 0)
end

local function descriptor_for(id)
  if id == nil then return default_descriptor() end
  local descriptor = BY_ID[id]
  if descriptor == nil then
    error(string.format('"%s" is not a compiler this toolchain knows: it provisions and pins what'
                        .. ' it drives, so a compiler with no published archive cannot be'
                        .. ' selected. It knows %s', tostring(id), known_names()), 0)
  end
  return descriptor
end

-- The asset basename is the home directory plus the platform, which is one
-- fact rather than two: every xpack archive unpacks to a directory named after
-- itself with the platform suffix removed.
local function asset_url(descriptor, release, os_name, arch)
  return string.format(
    "https://github.com/xpack-dev-tools/%s/releases/download/v%s/%s-%s-%s.%s",
    descriptor.project, release, string.format(descriptor.home, release),
    ASSET_OS[os_name], ASSET_ARCH[arch], ASSET_EXT[os_name])
end

--[[ @implNote `compiler` is optional and absent means the default, because
     daukle/cmake@1.0.0 pins this file and calls for_host with os, arch and
     version alone. Adding a field keeps that call answering the same row;
     changing the signature would break it until cmake re-pins. ]]
local function for_host(request)
  local descriptor = descriptor_for(request.compiler)
  local version = request.version
  local os_name = request.os
  local arch = request.arch

  local release = descriptor.releases[version]
  local digests = descriptor.digests[version]
  local key = tostring(os_name) .. "/" .. tostring(arch)
  if release == nil or digests == nil or digests[key] == nil then
    error(string.format('no pinned %s for c %s on this host (%s %s)', descriptor.binary,
                        tostring(version), tostring(os_name), tostring(arch)), 0)
  end

  local prerequisite = descriptor.prerequisite or PREREQUISITE
  return {
    url = asset_url(descriptor, release, os_name, arch),
    sha256 = digests[key],
    home = string.format(descriptor.home, release),
    binary = descriptor.binary,
    link_flags = descriptor.link_flags[os_name],
    missing_header = descriptor.missing_header,
    prerequisite = string.format(prerequisite[os_name], descriptor.binary),
  }
end

local function default_name()
  return default_descriptor().id
end

-- Only what a caller uses. This module is pinned by url and digest from other
-- repositories, so every name added here is a name they are then owed.
return { for_host = for_host, default_name = default_name }
