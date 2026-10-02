local RELEASES = { ["21"] = "21.1.8-1" }

-- One string where java and cmake both need a per-platform table: xpack does
-- not bundle on macOS, so there is no Contents/Home to fold in and every
-- archive's first member is xpack-clang-<version>/ with bin/ directly inside.
local HOME = "xpack-clang-%s"

-- daukle names the host; xpack names the file. The two disagree on every
-- field, so the tables are keyed on daukle's spelling and translated on the
-- way out.
local ASSET_OS = { linux = "linux", macos = "darwin", windows = "win32" }
local ASSET_ARCH = { x86_64 = "x64", aarch64 = "arm64" }
local ASSET_EXT = { linux = "tar.gz", macos = "tar.gz", windows = "zip" }

-- Transcribed from the .sha xpack publishes beside each asset. Never computed
-- from a file on disk: core.autocrlf rewrites line endings and a digest taken
-- from a working tree stops matching the published bytes.
local DIGESTS = {
  ["21"] = {
    ["linux/x86_64"]   = "0db58136aedb58b9af8c605a1b1570defbe06618f82bff60d24d3327f81d8321",
    ["linux/aarch64"]  = "be1eae2706c049ff9d1c5816e58bb5557d75810c9762cb929208472f7914617e",
    ["macos/x86_64"]   = "eab22258684105f5c32bb29772e2b17bc2ec4eac49b3c4d1775e45b3d1baf385",
    ["macos/aarch64"]  = "562270fc3029fbec56cadde80223efe2ea33e9fde46954582447afb4832310ea",
    ["windows/x86_64"] = "b23d38e2c1c539182919e147e7158fd8b4e8bdd9e6ddc5dfe06f6488c6d9d516",
  },
  -- xpack publishes no windows/aarch64 clang, so there is no entry for it and
  -- for_host raises naming the host. A table that is right by coincidence is
  -- one nobody checks when a row is added.
}

local function asset_url(release, os_name, arch)
  return string.format(
    "https://github.com/xpack-dev-tools/clang-xpack/releases/download/v%s/"
      .. "xpack-clang-%s-%s-%s.%s",
    release, release, ASSET_OS[os_name], ASSET_ARCH[arch], ASSET_EXT[os_name])
end

local function for_host(request)
  local version = request.version
  local os_name = request.os
  local arch = request.arch

  local release = RELEASES[version]
  local digests = DIGESTS[version]
  local key = tostring(os_name) .. "/" .. tostring(arch)
  if release == nil or digests == nil or digests[key] == nil then
    error(string.format('no pinned clang for c %s on this host (%s %s)',
                        tostring(version), tostring(os_name), tostring(arch)), 0)
  end

  return {
    url = asset_url(release, os_name, arch),
    sha256 = digests[key],
    home = string.format(HOME, release),
  }
end

return { for_host = for_host }
