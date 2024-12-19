--------------------------------------------------------------------
--- lazy.init.lua
--- 这段代码是lazy.nvim的核心，负责插件的加载、配置和管理。
--- 它使用了许多优化技术，例如缓存和延迟加载，以提高Neovim的启动速度。
--- 通过理解这段代码，你可以更好地理解Lazy.nvim的工作原理，并根据需要进行自定义。
--- bootstrap函数负责lazy.nvim自身，而setup函数则负责配置和加载你想要使用的其他插件。
--- 通过使用import功能，可以将插件配置模块化，使配置更加清晰和易于维护。
--------------------------------------------------------------------

-- 中文注释，告诉IDE Lazy是一个类，继承自LazyCommands
---@class Lazy: LazyCommands
-- 创建一个名为M的本地表，用于存储Lazy模块的函数和数据
local M = {}
-- 初始化一个_start变量，用于存储性能跟踪的开始时间
M._start = 0

-- 检查vim.uv库是否可用（用于异步操作）。如果不可用，则回退到vim.loop。
vim.uv = vim.uv or vim.loop

local function profile_require()
  -- done表用来跟踪哪些模块已被分析
  local done = {} ---@type table<string, true>
  -- 将原始的require函数存储在本地变量r中
  local r = require
  -- 重新定义require函数来包装于是功能
  _G.require = function(modname)
    local Util = package.loaded["lazy.core.util"]
    -- 检查模块名是否已在done表中
    if Util and not done[modname] then -- 不在done表中
      done[modname] = true -- 在done表中记录
      Util.track({ require = modname }) -- 使用Util.track跟踪模块请求
      local ok, ret = pcall(function()
        -- 调用原始的require函数并测量执行时间
        return vim.F.pack_len(r(modname))
      end)
      Util.track()
      if not ok then
        -- 如果报错，则抛异常
        error(ret, 2)
      end
      -- 返回所需模块
      return vim.F.unpack_len(ret)
    else -- 在done表中，则直接调用原始require加载模块
      return r(modname)
    end
  end
end

---@overload fun(opts: LazyConfig)
---@overload fun(spec:LazySpec, opts: LazyConfig)
function M.setup(spec, opts)
  -- 检查spec的类型
  --    如果spec是一个带有spec键的表，则假定它是一个完整的LazyConfig，并使用opts中提供的选项
  --    否则，假定spec是插件配置，并创建一个新的opts表，其中spec作为配置
  if type(spec) == "table" and spec.spec then
    ---@cast spec LazyConfig
    opts = spec
  else
    opts = opts or {}
    opts.spec = spec
  end

  -- 记录起始时间
  M._start = M._start == 0 and vim.uv.hrtime() or M._start
  -- 检查是否已设置标志vim.g.lazy_did_setup，以避免重新加载配置。
  if vim.g.lazy_did_setup then
    return vim.notify(
      "Re-sourcing your config is not supported with lazy.nvim",
      vim.log.levels.WARN,
      { title = "lazy.nvim" }
    )
  end
  -- 设定vim.g.lazy_did_setup,避免未来重复加载
  vim.g.lazy_did_setup = true


  if not vim.go.loadplugins then
    return
  end

  -- 执行各种Neovim和LuaJIT兼容性检查
  if vim.fn.has("nvim-0.8.0") ~= 1 then
    return vim.notify("lazy.nvim requires Neovim >= 0.8.0", vim.log.levels.ERROR, { title = "lazy.nvim" })
  end
  if not (pcall(require, "ffi") and jit and jit.version) then
    return vim.notify("lazy.nvim requires Neovim built with LuaJIT", vim.log.levels.ERROR, { title = "lazy.nvim" })
  end

  -- 启动一个定时器来跟踪设置时间
  local start = vim.uv.hrtime()

  -- use the Neovim cache if available
  if vim.loader and vim.fn.has("nvim-0.9.1") == 1 then
    package.loaded["lazy.core.cache"] = vim.loader
  end

  local Cache = require("lazy.core.cache")

  -- 根据opts中的performance.cache.enabled选项来设置是否启动缓存
  local enable_cache = vim.tbl_get(opts, "performance", "cache", "enabled") ~= false
  -- load module cache before anything else
  if enable_cache then
    Cache.enable()
  end

  -- 如果opts设置了profiling.require选项，则启动require函数的分析
  if vim.tbl_get(opts, "profiling", "require") then
    profile_require()
  end

  -- 使用lazy.stats模块跟踪"LazyStart"的开始
  require("lazy.stats").track("LazyStart")

  local Util = require("lazy.core.util")
  local Config = require("lazy.core.config")
  local Loader = require("lazy.core.loader")

  -- 将Loader.loader函数作为自定义加载器添加到Lua的包加载器列表中。
  table.insert(package.loaders, 3, Loader.loader)

  -- 如果设置了profiling.loader选项，则启用加载器的分析
  if vim.tbl_get(opts, "profiling", "loader") then
    if vim.loader then
      vim.loader._profile({ loaders = true })
    else
      Cache._profile_loaders()
    end
  end

  -- 使用Util.track跟踪插件设置的开始
  Util.track({ plugin = "lazy.nvim" }) -- setup start
  Util.track("module", vim.uv.hrtime() - start)

  -- load config
  Util.track("config")
  -- 调用Config.setup以处理opts中的插件配置
  Config.setup(opts)
  Util.track()

  -- setup loader and handlers
  -- 调用Loader.setup以设置插件加载器和处理程序
  Loader.setup()

  -- correct time delta and loaded
  -- 计算设置时间差并更新跟踪数据
  local delta = vim.uv.hrtime() - start
  Util.track().time = delta -- end setup
  -- 如果配置中存在lazy.nvim插件，则将其标记为已加载，并包含设置时间和源信息。
  if Config.plugins["lazy.nvim"] then
    Config.plugins["lazy.nvim"]._.loaded = { time = delta, source = "init.lua" }
  end

  -- load plugins with lazy=false or Plugin.init
  -- 调用Loader.startup以加载配置为lazy=false或具有自定义Plugin.init函数的插件。
  Loader.startup()

  -- all done!
  -- 在设置结束时触发模式为“LazyDone”的Neovim自动命令
  vim.api.nvim_exec_autocmds("User", { pattern = "LazyDone", modeline = false })
  -- 使用lazy.stats跟踪"LazyDone"的完成
  require("lazy.stats").track("LazyDone")
end

-- M.stats(): 返回lazy.stats模块的统计信息。
function M.stats()
  return require("lazy.stats").stats()
end

-- M.bootstrap(): 此函数负责克隆lazy.nvim仓库到本地，如果尚未克隆的话。
-- 它使用git clone命令，并指定克隆stable分支。然后将lazy.nvim的路径添加到rtp(runtimepath)中，以便Neovim可以找到并加载它。
function M.bootstrap()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable", -- latest stable release
      lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
end

---@return LazyPlugin[]
-- M.plugins(): 返回由lazy.core.config管理的所有插件的表。
function M.plugins()
  return vim.tbl_values(require("lazy.core.config").plugins)
end

-- 设置M的元表。
-- __index元方法允许通过M直接调用lazy.view.commands中的命令。例如，M.clean()实际上会调用require("lazy.view.commands").commands.clean()。
setmetatable(M, {
  __index = function(_, key)
    return function(...)
      return require("lazy.view.commands").commands[key](...)
    end
  end,
})

return M
