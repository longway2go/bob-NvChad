require "core"

-- vim.api 是Neovim提供的一组API，允许通过Lua脚本访问和控制编辑器的各种功能
-- vim.api.nvim_get_runtime_file() 用于查找运行时文件。
--     该接口有两个参数：
--     第一个参数：文件的相对路径
--     第二个参数：布尔值。如果为true，则返回所有匹配的文件路径。如果为false，则返回第一个找到的文件路径。

-- 针对这里的实际调用，分析如下：
-- 查找是否存在lua/custom/init.lua文件，如果存在，则记录在custom_init_path变量中
-- /lua/custom用于用户自定义配置，允许用户添加或修改默认配置，以满足个人需求
local custom_init_path = vim.api.nvim_get_runtime_file("lua/custom/init.lua", false)[1]

if custom_init_path then
  -- dofile()是Lua内置函数，用于加载并执行一个Lua文件。
  -- 如果custom_init_path所指定的文件存在，则会被执行。
  -- 这允许Neovim用户将自定义配置放在lua/custom/init.lua中，通过这种方式动态地加载和应用这些配置。
  -- 综上所述，这段代码的作用是检查是否存在一个用户自定义配置文件的路径（custom_init_path），如果这个路径存在，则执行该路径指向的 Lua 文件。这是一种灵活地扩展和个性化 Neovim 配置的方法，使得用户可以轻松地添加或修改默认配置，而无需直接修改主配置文件。这种模式提高了配置的可维护性和用户体验。
  dofile(custom_init_path)
end

-- load_mappings()并没有传参数进去，这样执行一遍又有什么意义呢？
require("core.utils").load_mappings()

-- vim.fn.stdpath() 是Neovim的内置API，用于获取标准路径。它可以返回一些常见的目录路径，例如配置文件目录、插件目录、数据文件目录等。
-- 该函数可以接受一个参数，用于指定要获取的数据类型。如：
-- 1. config: 返回配置文件目录的路径，通常是~/.vim或~/.config/nvim
-- 2. data: 返回数据文件目录的路径，通常是~/.vim或~/.local/share/nvim
-- 3. cache: 返回缓存文件目录的路径，通常是~/.vim或~/.cache/nvim
-- 4. vimfiles: 返回Vim插件的目录路径，通常是$VIM/vimfiles
-- 5. runtime: 返回Vim运行时文件目录的路径，通常是$VIMRUNTIME
--
-- 具体到这里，就是设置lazypath="~/.local/share/nvim/lazy/lazy.nvim/"
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

-- bootstrap lazy.nvim!
-- vim.loop.fs_stat()是Neovim的接口函数，用于获取文件的状态信息。
-- 输入参数：lazypath
-- 返回：一个包含文件状态信息的Lua表。这些文件状态信息包括文件类型、大小、修改时间等。
if not vim.loop.fs_stat(lazypath) then
  -- 如果lazypath路径所对应地文件不存在，则执行到这里
  -- 这样可以确保在文件不存在时进行必要的初始化操作。

  -- 生成chadrc模板。
  require("core.bootstrap").gen_chadrc_template()

  -- 加载lazypath路径所对应地文件。
  require("core.bootstrap").lazy(lazypath)
end

-- 执行~/.cache/nvim/defaults.lua文件
dofile(vim.g.base46_cache .. "defaults")
vim.opt.rtp:prepend(lazypath)
require "plugins"
