--[[ The raise is the assertion, because the plugin sandbox has no pcall: a
     chunk cannot catch an error, so the only way to observe a refusal is to
     let it end the sync. See the-table-answers-every-published-row for why the
     url below is never fetched.

     A fixture rather than a manifest because the host is not something a
     manifest can ask for: the plugin reads it from context.host, so the only
     way to assert the macOS answer from a Linux or Windows runner is to call
     for_host with that host directly. xpack publishes no macOS gcc at any
     version, which is the row this asserts is absent. ]]
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
    compilers.for_host{ os = "macos", arch = "aarch64", version = "15", compiler = "gcc" }
    return { ["report.txt"] = "xpack publishes a macOS gcc after all\n" }
  end,
}
