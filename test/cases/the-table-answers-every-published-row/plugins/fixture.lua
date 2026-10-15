--[[ The url and sha256 below are never fetched: the manifest overrides this
     alias with a local path, which is the only way to require a plugin that
     has no release yet. Replace both with the real coordinate once daukle/c is
     published. ]]
daukle.plugin{
  api = 1,
  requires = {
    cbase = {
      url = "https://example.invalid/daukle-c/plugin.lua",
      sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
    },
  },
}

local compilers = daukle.require("cbase:lib/compilers")

--[[ Every published row of every compiler in the registry, plus the same five
     hosts asked for with NO compiler at all. The default rows are the whole of
     4.1's compatibility obligation: daukle/cmake@1.0.0 pins this file and
     calls for_host without the key, so a default row that stopped equalling
     its clang row would break cmake at a release it cannot see coming. ]]
local PUBLISHED = {
  { compiler = nil,     version = "21", os = "linux",   arch = "x86_64" },
  { compiler = nil,     version = "21", os = "linux",   arch = "aarch64" },
  { compiler = nil,     version = "21", os = "macos",   arch = "x86_64" },
  { compiler = nil,     version = "21", os = "macos",   arch = "aarch64" },
  { compiler = nil,     version = "21", os = "windows", arch = "x86_64" },
  { compiler = "clang", version = "21", os = "linux",   arch = "x86_64" },
  { compiler = "clang", version = "21", os = "linux",   arch = "aarch64" },
  { compiler = "clang", version = "21", os = "macos",   arch = "x86_64" },
  { compiler = "clang", version = "21", os = "macos",   arch = "aarch64" },
  { compiler = "clang", version = "21", os = "windows", arch = "x86_64" },
  { compiler = "gcc",   version = "15", os = "linux",   arch = "x86_64" },
  { compiler = "gcc",   version = "15", os = "linux",   arch = "aarch64" },
  { compiler = "gcc",   version = "15", os = "windows", arch = "x86_64" },
}

daukle.toolchain{
  name = "fixture",
  generate = function()
    local lines = {}
    for index = 1, #PUBLISHED do
      local row = PUBLISHED[index]
      local pick = compilers.for_host{ os = row.os, arch = row.arch,
                                       version = row.version, compiler = row.compiler }
      lines[#lines + 1] = string.format("%s %s/%s %s %s %s %s %s",
                                        row.compiler or "default", row.os, row.arch,
                                        pick.binary, pick.url, pick.sha256, pick.home,
                                        pick.sdk_query and pick.sdk_query.tool or "-")
    end
    return { ["report.txt"] = table.concat(lines, "\n") .. "\n" }
  end,
}
