daukle.plugin{ api = 1, uses = { "provision", "exec" }, exports = { "lib/compilers" } }

local compilers = daukle.require("lib/compilers")

local KNOWN_KEYS = {
  version = true, sources = true, output = true, std = true, defines = true,
  includeDirs = true, compileArgs = true, linkArgs = true,
}

local function config_of(context)
  if context.toolchain ~= nil then return context.toolchain.config end
  return context.config
end

local function reject_unknown_keys(config)
  for key in pairs(config) do
    if KNOWN_KEYS[key] == nil then
      error(string.format('"%s" is not a key this toolchain knows: a misspelled key would'
                          .. ' otherwise be ignored and build the wrong thing silently', key), 0)
    end
  end
end

local function version_of(context)
  local version = (context.toolchain ~= nil and context.toolchain.version)
                  or config_of(context).version
  if version == nil then
    error('a c toolchain needs a "version": which clang to provision is not inferred', 0)
  end
  if type(version) ~= "string" or string.match(version, "^%d+$") == nil then
    error('a c toolchain version must be an exact major version such as "21", not a range:'
          .. ' this plugin pins its archives and does not match ranges', 0)
  end
  return version
end

local function string_list(value, key, plural, singular)
  if value == nil then return nil end
  if type(value) ~= "table" then
    error('"' .. key .. '" must be a list of ' .. plural .. ', not a ' .. type(value), 0)
  end
  local count = 0
  for _ in pairs(value) do count = count + 1 end
  if count ~= #value then
    error('"' .. key .. '" must be a list of ' .. plural .. ', not a table of named keys', 0)
  end
  for index = 1, #value do
    if type(value[index]) ~= "string" then
      error(string.format('"%s" must name a %s as a string, not a %s',
                          key, singular, type(value[index])), 0)
    end
  end
  return value
end

local function climbs_out(path)
  if string.match(path, "^/") ~= nil or string.match(path, "^%a:") ~= nil then return true end
  if string.find(path, "\\", 1, true) ~= nil then return true end
  if path == ".." or string.match(path, "^%.%./") ~= nil then return true end
  return string.find(path, "/../", 1, true) ~= nil or string.match(path, "/%.%.$") ~= nil
end

local function path_list(value, key, plural, singular)
  local list = string_list(value, key, plural, singular)
  if list == nil then return nil end
  for index = 1, #list do
    if climbs_out(list[index]) then
      error(string.format('"%s" may not climb out of the project, and "%s" does',
                          key, list[index]), 0)
    end
  end
  return list
end

--[[ @implNote the fold is what keeps src/a.c and src/sub/a.c apart, because
     the objects are flat: clang -c -o objects/a.o does not create objects/ and
     no verb does either, so there is nowhere else to put them. The fold is not
     injective (src_a.c folds onto src/a.c), which is why every object name is
     compared against every other one below rather than trusted. ]]
local function object_name(source)
  local stem = string.match(source, "^(.*)%.c$")
  if stem == nil then
    error(string.format('"%s" is not a C source: this toolchain compiles .c files, and C++ is'
                        .. ' not part of its surface', source), 0)
  end
  return (string.gsub(stem, "/", "_")) .. ".o"
end

local function objects_of(sources)
  local objects = {}
  local seen = {}
  for index = 1, #sources do
    local object = object_name(sources[index])
    if seen[object] ~= nil then
      error(string.format('"%s" and "%s" both compile to "%s": the objects are flat, so two'
                          .. ' sources whose paths differ only by a separator collide',
                          seen[object], sources[index], object), 0)
    end
    seen[object] = sources[index]
    objects[index] = object
  end
  return objects
end

local function sources_of(config)
  local sources = path_list(config.sources, "sources", "paths", "path")
  if sources == nil then
    error('a c toolchain needs "sources": the verb vocabulary cannot list a directory, so there'
          .. ' is no way to infer one', 0)
  end
  if #sources == 0 then
    error('"sources" is empty, so there is nothing to compile', 0)
  end
  return sources, objects_of(sources)
end

local function output_of(context, config)
  local output = config.output
  if output == nil then
    error('a c toolchain needs an "output": the name of the executable to link', 0)
  end
  if type(output) ~= "string" then
    error('"output" must name an executable as a string, not a ' .. type(output), 0)
  end
  if string.match(output, "^[%w_%-%.]+$") == nil then
    error(string.format('"output" is a name and not a path, and "%s" is not a name: a path would'
                        .. ' write a generated file somewhere daukle does not own', output), 0)
  end
  --[[ Windows will not execute a file whose name has no .exe, and clang adds
       none when -o is given, so a toolchain that passed the name through would
       write something the host cannot run. ]]
  if context.host.os == "windows" then return output .. ".exe" end
  return output
end

local function scalar_of(config, key, example)
  local value = config[key]
  if value == nil then return nil end
  if type(value) ~= "string" then
    error(string.format('"%s" must be a value such as "%s", not a %s', key, example, type(value)), 0)
  end
  return value
end

local function read(context)
  local config = config_of(context)
  reject_unknown_keys(config)
  local sources, objects = sources_of(config)
  return {
    version = version_of(context),
    sources = sources,
    objects = objects,
    output = output_of(context, config),
    std = scalar_of(config, "std", "c17"),
    defines = string_list(config.defines, "defines", "definitions", "definition"),
    includeDirs = path_list(config.includeDirs, "includeDirs", "directories", "directory"),
    compileArgs = string_list(config.compileArgs, "compileArgs", "arguments", "argument"),
    linkArgs = string_list(config.linkArgs, "linkArgs", "arguments", "argument"),
  }
end

daukle.toolchain{
  name = "c",
  generate = function(context)
    local spec = read(context)
    compilers.for_host{ os = context.host.os, arch = context.host.arch, version = spec.version }
    return {}
  end,
}

local function provision_clang(context, spec)
  local pick = compilers.for_host{ os = context.host.os, arch = context.host.arch,
                                   version = spec.version }
  local root = daukle.provision{
    url = pick.url,
    sha256 = pick.sha256,
    as = "clang " .. spec.version,
  }
  local suffix = context.host.os == "windows" and ".exe" or ""
  return root:tool(pick.home .. "/bin/clang" .. suffix)
end

--[[ @implNote only the headers the PLATFORM supplies. clang ships its own
     stddef.h, stdarg.h, limits.h and the rest of the builtin set inside the
     archive, so one of those going missing says the provisioned tree is
     incomplete and says nothing about the host. ]]
local LIBC_HEADERS = {
  ["assert.h"] = true, ["complex.h"] = true, ["ctype.h"] = true, ["errno.h"] = true,
  ["fenv.h"] = true, ["inttypes.h"] = true, ["locale.h"] = true, ["math.h"] = true,
  ["setjmp.h"] = true, ["signal.h"] = true, ["stdio.h"] = true, ["stdlib.h"] = true,
  ["string.h"] = true, ["tgmath.h"] = true, ["threads.h"] = true, ["time.h"] = true,
  ["uchar.h"] = true, ["wchar.h"] = true, ["wctype.h"] = true,
}

local PREREQUISITE = {
  linux = 'a provisioned clang carries its own builtin headers, linker and runtime, but not the'
          .. ' platform libc: install the libc development files, which are libc6-dev on Debian'
          .. ' and Ubuntu',
  macos = 'a provisioned clang carries its own builtin headers, linker and runtime, but not the'
          .. ' macOS SDK: install the Xcode command line tools with "xcode-select --install"',
  windows = 'this clang carries its own mingw-w64 sysroot, so a missing standard header means the'
            .. ' provisioned tree is incomplete rather than that the host is',
}

local function missing_standard_header(output)
  for header in string.gmatch(output, "'([^']+)' file not found") do
    if LIBC_HEADERS[header] then return header end
  end
  return nil
end

--[[ The sentence is appended and never substituted. D-19: a refusal whose
     stated reason is false about its own program costs more than no refusal at
     all, and rewriting every failing compile into "install libc6-dev" would be
     wrong for every genuine syntax error. ]]
local function run_clang(context, tool, argv)
  local result = daukle.exec(tool, argv, { capture = true, check = false })
  if result.code == 0 then return end

  local output = result.stderr
  if result.stdout ~= "" then
    output = output == "" and result.stdout or (output .. result.stdout)
  end
  -- Core already prefixes the task name, so naming the step here would read
  -- 'task "c:compile": c:compile failed'.
  local message = string.format("clang exited with code %d\n\n%s", result.code, output)
  local header = missing_standard_header(output)
  if header ~= nil then
    message = string.format('%s\nclang could not find the standard header "%s", and %s',
                            message, header, PREREQUISITE[context.host.os])
  end
  error(message, 0)
end

local function append(argv, extra)
  if extra == nil then return argv end
  for index = 1, #extra do argv[#argv + 1] = extra[index] end
  return argv
end

--[[ A table rather than a conditional, so the row that is wrong is visible as
     a row. Linux needs the pair to stop depending on an installed gcc and
     binutils; Windows and macOS were measured to need nothing. The flags are
     link-time, so -c never sees them and never warns that they went unused. ]]
local LINK_FLAGS = {
  linux = { "-fuse-ld=lld", "--rtlib=compiler-rt" },
  macos = {},
  windows = {},
}

daukle.task{
  name = "c:compile",
  run = function(context)
    local spec = read(context)
    local clang = provision_clang(context, spec)
    for index = 1, #spec.sources do
      local argv = { "-c", context.root .. "/" .. spec.sources[index], "-o", spec.objects[index] }
      if spec.std ~= nil then argv[#argv + 1] = "-std=" .. spec.std end
      if spec.defines ~= nil then
        for at = 1, #spec.defines do argv[#argv + 1] = "-D" .. spec.defines[at] end
      end
      if spec.includeDirs ~= nil then
        for at = 1, #spec.includeDirs do
          argv[#argv + 1] = "-I" .. context.root .. "/" .. spec.includeDirs[at]
        end
      end
      run_clang(context, clang, append(argv, spec.compileArgs))
    end
  end,
}

daukle.task{
  name = "c:link",
  dependsOn = { "c:compile" },
  run = function(context)
    local spec = read(context)
    local clang = provision_clang(context, spec)
    local argv = {}
    for index = 1, #spec.objects do argv[#argv + 1] = spec.objects[index] end
    argv[#argv + 1] = "-o"
    argv[#argv + 1] = spec.output
    append(argv, LINK_FLAGS[context.host.os])
    run_clang(context, clang, append(argv, spec.linkArgs))
  end,
}
