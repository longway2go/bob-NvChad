--------------------------------------------------------------------
--- lazy/core/config.lua
-- 定义lazy.nvim插件管理器的核心配置模块（LazyCoreConfig)。
-- 包括各种选项和初始化逻辑，为插件管理提供了基础。
-- 理解这些配置项和setup()的工作流程，可以帮助你更好地定制和使用lazy.nvim。
--------------------------------------------------------------------

-- 导入lazy.core.util中的实用函数
local Util = require("lazy.core.util")

-- 文档注释，表明此模块定义了LazyCoreConfig类
---@class LazyCoreConfig

-- 创建一个表M来存储配置选项
local M = {}

---@class LazyConfig
-- 定义一个包含lazy.nvim各个方面的默认设置的表。
M.defaults = {
  -- 插件的安装目录
  root = vim.fn.stdpath("data") .. "/lazy", -- directory where plugins will be installed

  defaults = {
    -- Set this to `true` to have all your plugins lazy-loaded by default.
    -- Only do this if you know what you are doing, as it can lead to unexpected behavior.
    -- 控制插件是否默认延迟加载
    lazy = false, -- should plugins be lazy-loaded?
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    -- 控制插件的版本控制行为（最新提交、特定版本等）
    version = nil, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
    -- default `cond` you can use to globally disable a lot of plugins
    -- when running inside vscode for example
    -- 一个函数，用于在特定环境下有条件的禁用插件
    cond = nil, ---@type boolean|fun(self:LazyPlugin):boolean|nil
  },
  -- leave nil when passing the spec as the first argument to setup()
  -- 定义要管理的插件的配置文件路径
  spec = nil, ---@type LazySpec
  -- 启用加载项目特定的.lazy.lua配置文件
  local_spec = true, -- load project specific .lazy.lua spec files. They will be added at the end of the spec.
  -- 用于跟踪已安装插件和版本的锁定文件路径
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json", -- lockfile generated after running update.
  ---@type number? limit the maximum amount of concurrent tasks
  -- 限制插件管理期间的并发任务数
  concurrency = jit.os:find("Windows") and (vim.uv.available_parallelism() * 2) or nil,
  -- 与Git使用相关的配置选项（日志命令、过滤选项等）
  git = {
    -- defaults for the `Lazy log` command
    -- log = { "--since=3 days ago" }, -- show commits from the last 3 days
    log = { "-8" }, -- show the last 8 commits
    timeout = 120, -- kill processes that take more than 2 minutes
    url_format = "https://github.com/%s.git",
    -- lazy.nvim requires git >=2.19.0. If you really want to use lazy with an older version,
    -- then set the below to false. This should work, but is NOT supported and will
    -- increase downloads a lot.
    filter = true,
    -- rate of network related git operations (clone, fetch, checkout)
    throttle = {
      enabled = false, -- not enabled by default
      -- max 2 ops every 5 seconds
      rate = 2,
      duration = 5 * 1000, -- in ms
    },
    -- Time in seconds to wait before running fetch again for a plugin.
    -- Repeated update/check operations will not run again until this
    -- cooldown period has passed.
    cooldown = 0,
  },
  -- 包管理的配置选项（缓存位置、源等）。
  pkg = {
    enabled = true,
    cache = vim.fn.stdpath("state") .. "/lazy/pkg-cache.lua",
    -- the first package source that is found for a plugin will be used.
    sources = {
      "lazy",
      "rockspec", -- will only be used when rocks.enabled is true
      "packspec",
    },
  },
  -- 使用luarocks或hererocks管理插件的配置选项
  rocks = {
    enabled = true,
    root = vim.fn.stdpath("data") .. "/lazy-rocks",
    server = "https://nvim-neorocks.github.io/rocks-binaries/",
    -- use hererocks to install luarocks?
    -- set to `nil` to use hererocks when luarocks is not found
    -- set to `true` to always use hererocks
    -- set to `false` to always use luarocks
    hererocks = nil,
  },
  -- 处理本地插件开发的配置
  dev = {
    -- Directory where you store your local plugin projects. If a function is used,
    -- the plugin directory (e.g. `~/projects/plugin-name`) must be returned.
    ---@type string | fun(plugin: LazyPlugin): string
    path = "~/projects",
    ---@type string[] plugins that match these patterns will use your local versions instead of being fetched from GitHub
    patterns = {}, -- For example {"folke"}
    fallback = false, -- Fallback to git when local plugin doesn't exist
  },
  -- 安装缺失插件和设置默认配色方案的选项
  install = {
    -- install missing plugins on startup. This doesn't increase startup time.
    missing = true,
    -- try to load one of these colorschemes when starting an installation during startup
    colorscheme = { "habamax" },
  },
  -- lazy.nvim用于界面额配置（大小、图标、自定义键等）。
  ui = {
    -- a number <1 is a percentage., >1 is a fixed size
    size = { width = 0.8, height = 0.8 },
    wrap = true, -- wrap the lines in the ui
    -- The border to use for the UI window. Accepts same border values as |nvim_open_win()|.
    border = "none",
    -- The backdrop opacity. 0 is fully opaque, 100 is fully transparent.
    backdrop = 60,
    title = nil, ---@type string only works when border is not "none"
    title_pos = "center", ---@type "center" | "left" | "right"
    -- Show pills on top of the Lazy window
    pills = true, ---@type boolean
    icons = {
      cmd = " ",
      config = "",
      event = " ",
      favorite = " ",
      ft = " ",
      init = " ",
      import = " ",
      keys = " ",
      lazy = "󰒲 ",
      loaded = "●",
      not_loaded = "○",
      plugin = " ",
      runtime = " ",
      require = "󰢱 ",
      source = " ",
      start = " ",
      task = "✔ ",
      list = {
        "●",
        "➜",
        "★",
        "‒",
      },
    },
    -- leave nil, to automatically select a browser depending on your OS.
    -- If you want to use a specific browser, you can define it here
    browser = nil, ---@type string?
    throttle = 1000 / 30, -- how frequently should the ui process render events
    custom_keys = {
      -- You can define custom key maps here. If present, the description will
      -- be shown in the help menu.
      -- To disable one of the defaults, set it to false.

      ["<localleader>l"] = {
        function(plugin)
          require("lazy.util").float_term({ "lazygit", "log" }, {
            cwd = plugin.dir,
          })
        end,
        desc = "Open lazygit log",
      },

      ["<localleader>i"] = {
        function(plugin)
          Util.notify(vim.inspect(plugin), {
            title = "Inspect " .. plugin.name,
            lang = "lua",
          })
        end,
        desc = "Inspect Plugin",
      },

      ["<localleader>t"] = {
        function(plugin)
          require("lazy.util").float_term(nil, {
            cwd = plugin.dir,
          })
        end,
        desc = "Open terminal in plugin dir",
      },
    },
  },
  -- Output options for headless mode
  -- 无头模式（没有UI）下的输出行为选项（进程输出、日志等）
  headless = {
    -- show the output from process commands like git
    process = true,
    -- show log messages
    log = true,
    -- show task start/end
    task = true,
    -- use ansi colors
    colors = true,
  },
  -- 用于显示插件差异的命令（浏览器、git、终端等）。
  diff = {
    -- diff command <d> can be one of:
    -- * browser: opens the github compare view. Note that this is always mapped to <K> as well,
    --   so you can have a different command for diff <d>
    -- * git: will run git diff and open a buffer with filetype git
    -- * terminal_git: will open a pseudo terminal with git diff
    -- * diffview.nvim: will open Diffview to show the diff
    cmd = "git",
  },
  -- 自动插件更新检查的选项
  checker = {
    -- automatically check for plugin updates
    enabled = false,
    concurrency = nil, ---@type number? set to 1 to check for updates very slowly
    notify = true, -- get a notification when new updates are found
    frequency = 3600, -- check for updates every hour
    check_pinned = false, -- check for pinned packages that can't be updated
  },
  -- 启用配置文件更改时自动重新加载UI
  change_detection = {
    -- automatically check for config file changes and reload the ui
    enabled = true,
    notify = true, -- get a notification when changes are found
  },
  -- 性能优化选项（缓存、运行时路径管理等）
  performance = {
    cache = {
      enabled = true,
    },
    reset_packpath = true, -- reset the package path to improve startup time
    rtp = {
      reset = true, -- reset the runtime path to $VIMRUNTIME and your config directory
      ---@type string[]
      paths = {}, -- add any custom paths here that you want to includes in the rtp
      ---@type string[] list any plugins you want to disable here
      disabled_plugins = {
        -- "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        -- "tarPlugin",
        -- "tohtml",
        -- "tutor",
        -- "zipPlugin",
      },
    },
  },
  -- lazy can generate helptags from the headings in markdown readme files,
  -- so :help works even for plugins that don't have vim docs.
  -- when the readme opens with :help it will be correctly displayed as markdown
  -- 从markdown自述文件生成插件帮助标签的配置
  readme = {
    enabled = true,
    root = vim.fn.stdpath("state") .. "/lazy/readme",
    files = { "README.md", "lua/**/README.md" },
    -- only generate markdown helptags for plugins that don't have docs
    skip_if_doc_exists = true,
  },
  -- 检查器和其他功能使用的状态文件路径
  state = vim.fn.stdpath("state") .. "/lazy/state.json", -- state info for checker and other things
  -- Enable profiling of lazy.nvim. This will add some overhead,
  -- so only enable this when you are debugging lazy.nvim
  -- 启用lazy.nvim的性能分析以进行调试
  profiling = {
    -- Enables extra stats on the debug tab related to the loader cache.
    -- Additionally gathers stats about all package.loaders
    loader = false,
    -- Track each new require in the Lazy profiling tab
    require = false,
  },
  -- 启用调试模式
  debug = false,
}

-- hererocks(): 确定是否使用hererocks进行luarocks安装
function M.hererocks()
  if M.options.rocks.hererocks == nil then
    M.options.rocks.hererocks = vim.fn.executable("luarocks") == 0
  end
  return M.options.rocks.hererocks
end

-- version: 存储lazy.nvim的当前版本
M.version = "11.16.2" -- x-release-please-version

-- 使用nvim_create_namespace为lazy.nvim创建一个命名空间
M.ns = vim.api.nvim_create_namespace("lazy")

---@type LazySpecLoader
-- 用于存储规范加载器对象
M.spec = nil

---@type table<string, LazyPlugin>
-- 存储已加载插件的表
M.plugins = {}

---@type LazyPlugin[]
-- 要清理的插件列表
M.to_clean = {}

---@type LazyConfig
-- 存储合并默认值和用户提供的选项后的最终配置选项
M.options = {}

---@type string
-- 当前配置文件的路径
M.me = nil

---@type string
-- 存储用户的mapleader键映射
M.mapleader = nil

---@type string
-- 存储用户的maplocalleader键映射
M.maplocalleader = nil

-- 指示Neovim当前是否处于挂起状态的标志
M.suspended = false

-- 检查Neovim是否是在无头模式下运行
function M.headless()
  return not M.suspended and #vim.api.nvim_list_uis() == 0
end

---@param opts? LazyConfig
-- setup(): 设置函数
-- 执行以下操作：
--    将默认选项和用户提供的选项合并到M.options中
--    规范化各种配置选项的路径
--    如果启用，则设置运行时路径rtp管理
--    初始化M.me和M.mapleader变量
--    根据无头模式为不同事件创建自动命令：
--        在UI模式下：
--            设置UI命令
--            启用配置更改检测和更新检查器
--            提供自动命令以在更改.lazy.lua、pkg.json或.rockspec文件时重新加载插件
--            处理挂起/恢复事件
--        在无头模式下：
--            设置无头操作的命令。
--    调用Util.very_lazy()执行其他延迟初始化任务
-- 返回值：
--    返回包含配置和辅助函数的M表，供lazy.nvim的其他部分使用。
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})

  if type(M.options.spec) == "string" then
    M.options.spec = { import = M.options.spec }
  end
  table.insert(M.options.install.colorscheme, "habamax")

  -- root
  M.options.root = Util.norm(M.options.root)
  if type(M.options.dev.path) == "string" then
    M.options.dev.path = Util.norm(M.options.dev.path)
  end
  M.options.lockfile = Util.norm(M.options.lockfile)
  M.options.readme.root = Util.norm(M.options.readme.root)

  vim.fn.mkdir(M.options.root, "p")

  if M.options.performance.reset_packpath then
    vim.go.packpath = vim.env.VIMRUNTIME
  end

  M.me = debug.getinfo(1, "S").source:sub(2)
  M.me = Util.norm(vim.fn.fnamemodify(M.me, ":p:h:h:h:h"))
  local lib = vim.fn.fnamemodify(vim.v.progpath, ":p:h:h") .. "/lib"
  lib = vim.uv.fs_stat(lib .. "64") and (lib .. "64") or lib
  lib = lib .. "/nvim"
  if M.options.performance.rtp.reset then
    ---@type vim.Option
    vim.opt.rtp = {
      vim.fn.stdpath("config"),
      vim.fn.stdpath("data") .. "/site",
      M.me,
      vim.env.VIMRUNTIME,
      lib,
      vim.fn.stdpath("config") .. "/after",
    }
  end
  for _, path in ipairs(M.options.performance.rtp.paths) do
    vim.opt.rtp:append(path)
  end
  vim.opt.rtp:append(M.options.readme.root)

  -- disable plugin loading since we do all of that ourselves
  vim.go.loadplugins = false
  M.mapleader = vim.g.mapleader
  M.maplocalleader = vim.g.maplocalleader

  vim.api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = function()
      require("lazy.stats").on_ui_enter()
    end,
  })

  if M.headless() then
    require("lazy.view.commands").setup()
  else
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = function()
        require("lazy.view.commands").setup()
        if M.options.change_detection.enabled then
          require("lazy.manage.reloader").enable()
        end
        if M.options.checker.enabled then
          vim.defer_fn(function()
            require("lazy.manage.checker").start()
          end, 10)
        end

        -- useful for plugin developers when making changes to a packspec file
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = { "lazy.lua", "pkg.json", "*.rockspec" },
          callback = function()
            local plugin = require("lazy.core.plugin").find(vim.uv.cwd() .. "/lua/")
            if plugin then
              require("lazy").pkg({ plugins = { plugin } })
            end
          end,
        })

        vim.api.nvim_create_autocmd({ "VimSuspend", "VimResume" }, {
          callback = function(ev)
            M.suspended = ev.event == "VimSuspend"
          end,
        })
      end,
    })
  end

  Util.very_lazy()
end

return M
