-- 用于对Neovim选项进行配置
local opt = vim.opt
local g = vim.g

-- 合并配置表之后，记录在config变量中
local config = require("core.utils").load_config()

-------------------------------------- globals -----------------------------------------
-- 存储当前使用的NvChad主题
g.nvchad_theme = config.ui.theme
-- 定义base46主题缓存的路径
g.base46_cache = vim.fn.stdpath "data" .. "/nvchad/base46/"
-- 设置用于切换主题的图标
g.toggle_theme_icon = "   "
-- 根据配置启用或禁用UI透明度
g.transparency = config.ui.transparency

-------------------------------------- options ------------------------------------------
-- [状态栏]
-- 设置全局状态栏为第3行
opt.laststatus = 3 -- global statusline
-- 隐藏模式指示符（Normal, Insert，Visual）
opt.showmode = false

-- [剪贴板&光标行]
-- 使用未命名剪贴板（粘贴后，内容不会覆盖之前的内容。）
opt.clipboard = "unnamedplus"
-- 高亮显示光标所在行
opt.cursorline = true

-- Indenting
-- [缩进]
-- 用空格代替制表符
opt.expandtab = true
-- 用两个空格进行缩进
opt.shiftwidth = 2
-- 智能缩进，根据上下文自动调整缩进级别
opt.smartindent = true
-- 将TAB键视为2个空格
opt.tabstop = 2
-- 编辑文本时，将TAB键显示为2个空格
opt.softtabstop = 2

-- [字符填充&大小写敏感性]
-- 在行尾用空格填充空白区域
opt.fillchars = { eob = " " }
-- 忽略大小写
opt.ignorecase = true
-- 当搜索或替换文本时，根据上下文智能判断大小写
opt.smartcase = true

-- [鼠标]
-- 启用所有鼠标操作模式
opt.mouse = "a"

-- Numbers
-- [编号]
-- 显示行号
opt.number = true
-- 设置行号宽度为2个字符
opt.numberwidth = 2
-- 禁用标尺
opt.ruler = false

-- disable nvim intro
-- 禁用nvim启动信息
opt.shortmess:append "sI"

-- 显示签名列
opt.signcolumn = "yes"

-- [窗口分割]
-- 垂直分割窗口（在新窗口的当前窗口下方）
opt.splitbelow = true
-- 水平分割窗口（在新窗口的当前窗口右侧）
opt.splitright = true

-- 启用终端颜色
opt.termguicolors = true

-- 设置闲置超时时间为400ms（长达400ms为操作时，会执行一些自动动作）
opt.timeoutlen = 400

-- 启用Neovim的撤销历史记录功能
opt.undofile = true

-- interval for writing swap file to disk, also used by gitsigns
-- 将交换文件写入磁盘的时间时间设置为250ms
opt.updatetime = 250

-- go to previous/next line with h,l,left arrow and right arrow
-- when cursor reaches end/beginning of line
-- 允许使用左右箭头键和h/l命令在行首/尾进行导航，即使光标已经在行首/行尾
opt.whichwrap:append "<>[]hl"

-- 将空格设置为全局Leader键，用于激活各种映射命令
g.mapleader = " "

-- disable some default providers
-- 禁止所罗列的4个语言的LSP提供程序
-- vim.g["loaded_node_provider"] = 0
-- vim.g["loaded_perl_provider"] = 0
-- vim.g["loaded_python3_provider"] = 0
-- vim.g["loaded_ruby_provider"] = 0
for _, provider in ipairs { "node", "perl", "python3", "ruby" } do
  vim.g["loaded_" .. provider .. "_provider"] = 0
end

-- add binaries installed by mason.nvim to path
-- 用于将mason.nvim的二进制可执行文件添加到path中
-- 如果是windows电脑，则path追加内容用;分隔
-- 如果不是windows电脑，则path追加内容用:分隔
local is_windows = vim.loop.os_uname().sysname == "Windows_NT"
vim.env.PATH = vim.fn.stdpath "data" .. "/mason/bin" .. (is_windows and ";" or ":") .. vim.env.PATH

-------------------------------------- autocmds ------------------------------------------
-- 创建自动命令函数
-- 需要指定触发条件、模式、回调函数等参数，才能实现完整的功能
--
-- 自动命令可以根据各种事件触发，例如文件类型改变、缓冲区保存、窗口创建等
-- 可以使用模式来限制自动命令的触发范围，例如特定文件类型、特定命令行模式等
-- 回调函数定义了自动命令执行时要采取的操作。
local autocmd = vim.api.nvim_create_autocmd

-- dont list quickfix buffers
-- 隐藏快速修复缓冲区
-- 触发条件: FileType 事件，即文件类型发生变化时。
autocmd("FileType", {
  -- 只针对文件后缀类型为qf的，即缓冲区
  pattern = "qf",
  callback = function()
    -- 将该缓冲区从缓冲区列表中隐藏
    vim.opt_local.buflisted = false
  end,
})

-- reload some chadrc options on-save
-- 在用户保存自定义配置文件时自动重新加载相关配置，无需手动重启 Neovim
autocmd(
  -- 触发条件: BufWritePost 事件，即缓冲区内容保存后触发。
  "BufWritePost",
  {
    -- 模式: 使用 vim.tbl_map 和 vim.fn.glob 函数生成一个模式列表，匹配所有位于 config/lua/custom/**/*.lua 路径下的 Lua 文件 (可能包含用户自定义配置)。
    pattern = vim.tbl_map(
      function(path)
          return vim.fs.normalize(vim.loop.fs_realpath(path))
      end,
      vim.fn.glob(vim.fn.stdpath "config" .. "/lua/custom/**/*.lua", true, true, true)
    ),
    -- 分组: group = vim.api.nvim_create_augroup("ReloadNvChad", {}): 创建名为 "ReloadNvChad" 的自动命令组，用于将相关命令归类。
    group = vim.api.nvim_create_augroup("ReloadNvChad", {}),
    callback = function(opts)
      local fp = vim.fn.fnamemodify(vim.fs.normalize(vim.api.nvim_buf_get_name(opts.buf)), ":r") --[[@as string]]
      local app_name = vim.env.NVIM_APPNAME and vim.env.NVIM_APPNAME or "nvim"
      local module = string.gsub(fp, "^.*/" .. app_name .. "/lua/", ""):gsub("/", ".")

      require("plenary.reload").reload_module "base46"
      require("plenary.reload").reload_module(module)
      require("plenary.reload").reload_module "custom.chadrc"

      config = require("core.utils").load_config()

      vim.g.nvchad_theme = config.ui.theme
      vim.g.transparency = config.ui.transparency

      -- statusline
      require("plenary.reload").reload_module("nvchad.statusline." .. config.ui.statusline.theme)
      vim.opt.statusline = "%!v:lua.require('nvchad.statusline." .. config.ui.statusline.theme .. "').run()"

      -- tabufline
      if config.ui.tabufline.enabled then
          require("plenary.reload").reload_module "nvchad.tabufline.modules"
          vim.opt.tabline = "%!v:lua.require('nvchad.tabufline.modules').run()"
      end

      require("base46").load_all_highlights()
      -- vim.cmd("redraw!")
    end
  }
)

-------------------------------------- commands ------------------------------------------
local new_cmd = vim.api.nvim_create_user_command

-- 创建用户自定义命令NvChadUpdate
-- 当用户输入 :NvChadUpdate 时，Neovim 会调用此函数进行处理。
new_cmd("NvChadUpdate", function()
  require "nvchad.updater"()
end, {})
