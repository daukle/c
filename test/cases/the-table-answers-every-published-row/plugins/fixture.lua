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

local PUBLISHED = {
  { os = "linux", arch = "x86_64" },
  { os = "linux", arch = "aarch64" },
  { os = "macos", arch = "x86_64" },
  { os = "macos", arch = "aarch64" },
  { os = "windows", arch = "x86_64" },
}

daukle.toolchain{
  name = "fixture",
  generate = function()
    local lines = {}
    for index = 1, #PUBLISHED do
      local host = PUBLISHED[index]
      local pick = compilers.for_host{ os = host.os, arch = host.arch, version = "21" }
      lines[#lines + 1] = string.format("%s/%s %s %s %s", host.os, host.arch,
                                        pick.url, pick.sha256, pick.home)
    end
    return { ["report.txt"] = table.concat(lines, "\n") .. "\n" }
  end,
}
