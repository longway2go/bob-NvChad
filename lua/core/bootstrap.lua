local M = {}

-- vim.fn是Vim编辑器的一个函数接口，用于调用VimL（Vim脚本语言）函数。
-- 通过vim.fn，可以在Lua脚本中调用VimL函数来实现更多的功能，从而扩展Lua脚本。
local fn = vim.fn

-- 调用M.echo()，会清除屏幕后，加粗显示str变量中的内容。
M.echo = function(str)
  -- 强制重绘屏幕，以确保更新的内容能够立即显示。
  vim.cmd "redraw"

  -- vim.api.nvim_echo()是NeoVim中的一个Lua API，用于在屏幕上显示自定义的文本。
  -- 通过调用该接口，可以在Neovim中灵活地显示自定义的文本，并根据需求选择是否清除屏幕上的其它内容。
  -- 
  -- 语法为：
  --     vim.api.nvim_echo(items, topline, options)
  --
  -- 参数说明：
  --   items: 一个包含文本和高亮属性的Lua表。每个元素是一个包含两个元素的子表，第一个元素为要显示的文本，第二个元素为该文本的高亮属性。
  --   topline: 布尔值，表示是否清除屏幕上的其它内容。true：清除。false：追加显示。
  --   options: 选项表，用于设置其它显示选项。可选字段包括：
  --            on_event: 字符串，指定在显示文本后执行的事件。
  --            delay: 整数，以毫秒为单位的延迟时间，表示在显示文本后多长时间执行事件。
  vim.api.nvim_echo({ { str, "Bold" } }, true, {})
end

-- 自定义local shell_call()的Lua函数，用于在NeoVim中执行系统命令并检查是否成功。
local function shell_call(args)
  -- vim.fn.system(cmd)
  -- 是Neovim中的VimL函数，用于在Vim启动的shell中执行系统命令，并返回命令的输出结果。
  -- cmd: 要执行的系统命令，可以是一个字符串。
  -- 用于执行系统命令，并将输出结果存储在output变量中。
  local output = fn.system(args)

  -- 使用assert来检查执行命令的返回值。
  -- 如果返回值非零，则抛出一个错误，提示外部调用失败，并将错误码和命令输出一同显示出来。
  -- 否则，函数执行完毕，没有返回值。
  assert(vim.v.shell_error == 0, "External call failed with error code: " .. vim.v.shell_error .. "\n" .. output)
end

-- M.lazy()
-- 用来安装和配置一些插件和主题的初始化函数
M.lazy = function(install_path)
  ------------- base46 ---------------
  -- lazy_path = ~/.local/share/nvim/lazy/base46 --> 这是一个目录
  local lazy_path = fn.stdpath "data" .. "/lazy/base46"

  M.echo "  Compiling base46 theme to bytecode ..."

  -- 从base46 GitHub仓库中下载该工程代码，将其存放在lazy_path变量指定的位置，即~/.local/share/nvim/lazy/base46/下
  local base46_repo = "https://github.com/NvChad/base46"
  shell_call { "git", "clone", "--depth", "1", "-b", "v2.0", base46_repo, lazy_path }
  -- vim.opt是Vim的选项对象，通过它可以访问和设置各种Vim的选项。可以以面向对象的方式来操作和管理Vim的选项。
  -- vim.opt.rtp是Vim的runtimepath(rtp)选项的访问方式。rtp选项指定了Vim在哪些目录中查找插件、脚本和其他运行时的文件。
  -- vim.opt.rtp:prepend() 为在rtp选项开头添加形参中指定的路径
  -- 在这里，便是将~/.local/share/nvim/lazy/base46添加到Vim的runtimepath的开头，以便Vim可以在该路径中查找插件和脚本文件。
  vim.opt.rtp:prepend(lazy_path)

  -- ?
  -- 说是用来编译base46主题
  -- Base46是一种将二进制数据转换为文本表示形式的编码方案。它使用46个字符来标识256个可能的字节值，从而将数据扩展为原来的1.84倍。
  -- vim.g.base46_cache缓存了最近使用的Base46编码/解码结果，以便提高性能。
  -- vim.g.base46_cache是一个文件夹,位于~/.config/nvim/plugins/base46目录下。这个位置不知道对不对??我没有找到。
  -- 将主题读取之后，写入都vim.g.base46_cache所指代的位置，以便于提升后续的加载速度。
  -- ???如果按照这个lazy_path是找不到lua文件的，又是怎么引入的base46lua包，调用的compile()呢？
  require("base46").compile()

  -- 将lazy.vim下载到install_path中指定的位置
  -- 实际上，install_path=~/.local/share/nvim/lazy/lazy.nvim/
  --------- lazy.nvim ---------------
  M.echo "  Installing lazy.nvim & plugins ..."
  local repo = "https://github.com/folke/lazy.nvim.git"
  shell_call { "git", "clone", "--filter=blob:none", "--branch=stable", repo, install_path }
  -- 将`~/.local/share/nvim/lazy/lazy.nvim/`的路径追加在Vim运行时路径最前面。
  vim.opt.rtp:prepend(install_path)

  -- install plugins
  -- 说是用来安装其他插件
  require "plugins" -- 这个包是从哪里来？

  -- mason packages & show post_bootstrap screen
  -- 用来执行mason packages和显示post_bootstrap界面
  require "nvchad.post_install"() -- 这个怎么加载到的，我没有找到对应模块
end

-- [[
-- 定义M.gen_chadrc_template()，用于生成NeoVim的自定义配置文件模板。
-- 自定义配置文件模板的文件路径为：~/.config/nvim/lua/custom/
--
-- 会提示是否安装示例自定义配置。
-- 如果输入y，则从https://github.com/NvChad/example_config中下载。
-- 如果输入其它，则只创建一个~/.config/nvim/lua/custom/chadrc.lua文件，里面写一句话："---@type ChadrcConfig\nlocal M = {}\n\nM.ui = { theme = 'onedark' }\n\nreturn M"
-- ]]
M.gen_chadrc_template = function()
  -- path = ~/.config/nvim/lua/custom/
  local path = fn.stdpath "config" .. "/lua/custom"

  -- vim.fn.isdirectory(path)是NeoVim的VimL函数，用于检查指定路径是否是一个目录
  -- path: 待检查的路径，可以是一个字符串。
  -- 如果给定路径存在且是一个目录，则返回1；
  -- 否则，返回0.
  if fn.isdirectory(path) ~= 1 then
    -- 若进来，则认为~/.config/nvim/lua/custom/为空

    -- vim.fn.input(prompt)是NeoVim的VimL函数，用于从用户获取输入。
    -- prompt: 要显示给用户的提示信息，可以是一个字符串
    -- 该函数会在Vim启动的shell中显示给定的提示信息，并等待用户输入。用户输入完成后，函数会将用户输入的内容作为字符串返回。
    -- 这个接口在需要与用户进行交互的脚本中很有用，例如询问用户是否执行某个操作或者获取用户的配置选项。
    --
    -- 这里提示用户“是否要安装预配置内容”
    -- input变量用于记录用户交互录入的结果
    local input = fn.input "Do you want to install example custom config? (y/N): "

    if input:lower() == "y" then
      -- 如果用户输入y，则认为要安装预配置内容，则进入到这里

      -- 加粗显示"Cloning example custom config repo..."
      M.echo "Cloning example custom config repo..."

      -- NeoVim中执行命令：git clone --depth 1 https://github.com/NvChad/example_config ~/.config/nvim/lua/custom/
      shell_call { "git", "clone", "--depth", "1", "https://github.com/NvChad/example_config", path }

      -- vim.fn.delete() 是NeoVim的VimL函数，用于删除文件或目录。
      -- 语法：
      --      vim.fn.delete({path}, {recursive})
      -- 参数说明：
      --   {path}: 要删除的文件或目录路径，可以是一个字符串。
      --   {recursive}: 可选参数，表示是否递归删除目录及其内容。默认为0（不递归）
      --
      -- 这里，强制删除~/.config/nvim/lua/custom/.git/目录
      -- 貌似传入的"rf"参数不对哦~~？？？
      fn.delete(path .. "/.git", "rf")
    else
      -- 如果用户输入不是y，则认为不安装预配置内容，则进入到这里

      -- use very minimal chadrc
      -- vim.fn.mkdir()是VimL函数，用于创建目录。
      -- 语法：
      --      vim.fn.mkdir(path, mode)
      -- 参数说明：
      --    path: 要创建的目录路径，可以是一个字符串。
      --    mode: 可选参数，表示要设置的权限模式。默认为0777。
      -- AI上查到，不该使用"p"作为第二个参数。难道API版本不同步？
      fn.mkdir(path, "p")

      -- 向~/.config/nvim/lua/custom/chadrc.lua中写入内容
      -- [[
      -- ---@type ChadrcConfig
      -- local M = {}
      --
      -- M.ui = { theme = 'onedark' }
      --
      -- return M
      -- ]]
      local file = io.open(path .. "/chadrc.lua", "w")
      if file then
        file:write "---@type ChadrcConfig\nlocal M = {}\n\nM.ui = { theme = 'onedark' }\n\nreturn M"
        file:close()
      end
    end
  end
end

return M
