--[[ The raise is the assertion, because the plugin sandbox has no pcall: a
     chunk cannot catch an error, so the only way to observe a refusal is to
     let it end the sync. See the-table-answers-every-published-row for why the
     url below is never fetched. ]]
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

daukle.toolchain{
  name = "fixture",
  generate = function()
    compilers.for_host{ os = "windows", arch = "aarch64", version = "21" }
    return { ["report.txt"] = "xpack publishes a windows/aarch64 clang after all\n" }
  end,
}
