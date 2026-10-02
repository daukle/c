--[[ See the-table-answers-every-published-row: the alias is overridden with a
     local path because daukle/c has no release yet. ]]
daukle.plugin{
  api = 1,
  requires = {
    cbase = {
      url = "https://example.invalid/daukle-c/plugin.lua",
      sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
    },
  },
}

-- Requiring the base is what this case is about: the module arrives, and the
-- base's own tasks do not come with it.
local compilers = daukle.require("cbase:lib/compilers")

daukle.toolchain{
  name = "fixture",
  generate = function(context)
    compilers.for_host{ os = context.host.os, arch = context.host.arch, version = "21" }
    return {}
  end,
}
