local M = {}

-- vim.tbl_deep_extend()是neovim内置接口，用于深度合并多个Lua表。
local merge_tb = vim.tbl_deep_extend

-- load_config()
-- 函数作用：加载配置。将chadrc和default config的内容进行合并。以chadrc中的配置为主。
-- 配置来源为两处：
-- 1. lua/core/default_config
-- 2. lua/custom/chadrc
-- 会将两者的配置项进行合并。若键名重复，2为用户自定义内容，会替换1（默认配置内容）中的重名键值。
-- 目的就是用户可以对插件进行客制化配置。
M.load_config = function()
  -- 加载core/default_config.lua文件
  local config = require "core.default_config"

  -- 查找运行时文件：lua/custom/chadrc.lua
  -- 如果存在，将首个匹配结果记录在chadrc_path中
  local chadrc_path = vim.api.nvim_get_runtime_file("lua/custom/chadrc.lua", false)[1]

  -- 若chadrc_path存在
  if chadrc_path then
    -- 加载并执行chadrc_path，即lua/custom/chadrc.lua
    -- 将结果记录在chadrc变量中
    local chadrc = dofile(chadrc_path)

    -- 第一个形参：chadrc.mappings，即lua/custom/mappings模块
    -- 第二个形参：config.mappings，即lua/core/mappings模块
    -- 将config.mappings中与chadrc.mappings重复的快捷键项删除
    config.mappings = M.remove_disabled_keys(chadrc.mappings, config.mappings)

    -- 合并config表与chadrc表。如果键值相同，则chadrc键值有效。
    -- 由于上一步已经删除了config中与chadrc重复的内容，所以，这里再次合并时，mappings内部的内容是直接合并，没有重复项存在的。
    -- 不明白为什么要做上面的一步。难道这个merge_tb()不能遍merge吗？
    config = merge_tb("force", config, chadrc)
    config.mappings.disabled = nil
  end

  return config
end

-- remove_disabled_keys()
-- 参数 chadrc_mappings : 自定义mappings
-- 参数 default_mappings: 默认mappings
-- return: default_mappings
--
-- 函数作用: 针对default_mappings，删除chadrc_mappings中有的内容，然后返回default_mappings
--           这个也容易理解，因为要用用户配置的内容覆盖掉default_mappings中的内容
M.remove_disabled_keys = function(chadrc_mappings, default_mappings)
  -- 如果chadrc_mappings为空，则不作处理
  if not chadrc_mappings then
    return default_mappings
  end

  -- store keys in a array with true value to compare
  -- keys_to_disable存放的是一个二维数组,[mode][k]
  --     其中，mode为n,v之类的一级表名
  --     k为表下的键值
  -- 默认，设置keys_to_disable[mode][k] = true
  local keys_to_disable = {}
  for _, mappings in pairs(chadrc_mappings) do
    for mode, section_keys in pairs(mappings) do
      if not keys_to_disable[mode] then
        keys_to_disable[mode] = {}
      end
      section_keys = (type(section_keys) == "table" and section_keys) or {}
      for k, _ in pairs(section_keys) do
        keys_to_disable[mode][k] = true
      end
    end
  end

  -- make a copy as we need to modify default_mappings
  for section_name, section_mappings in pairs(default_mappings) do
    for mode, mode_mappings in pairs(section_mappings) do
      mode_mappings = (type(mode_mappings) == "table" and mode_mappings) or {}
      for k, _ in pairs(mode_mappings) do
        -- if key if found then remove from default_mappings
        if keys_to_disable[mode] and keys_to_disable[mode][k] then
          -- 若chadrc_mappings中有的快捷键，将default_mappings中对应的内容删除。
          default_mappings[section_name][mode][k] = nil
        end
      end
    end
  end

  -- 返回default_mappings，里面已经删除了chadrc_mappings中有的内容
  return default_mappings
end

-- [[
-- 这段代码是一个 Lua 函数，用于在 Neovim 中加载和应用键位映射。它是为了提高 Neovim 用户自定义配置的灵活性和可维护性而设计。
-- 函数执行步骤：
--    函数在vim加载成功之后才去执行。
--    函数一开始会从chadrc和default_config中读取配置，并进行合并。
--    之后，会根据传入的section和mappings_opt再次进行合并。
--    最后，通过调用vim.keymap.set()来设置快捷键
-- 
-- 函数名：load_mappings
-- 参数 section: 指定了要加载映射的部分或类别。如果为nil，则加载所有映射。
-- 参数 mapping_opt: 可选参数，提供了默认的映射选项，这些选项将应用于所有键位映射，除非被具体映射的选项覆盖。
--                   mapping_opt是给了另一种客制化mappings的方法
-- ]]
M.load_mappings = function(section, mapping_opt)
  -- vim.schedule()接口会将函数的执行推迟到Neovim准备好执行Lua函数时。
  vim.schedule(function()
    -- 内部自定义函数，用于实际设置给定部分的键位映射
    local function set_section_map(section_values)
      -- 忽略插件专用映射
      -- 如果section_values.plugin存在，则意味着该部分映射是专为插件定义的。此时直接返回，不去处理这些映射
      if section_values.plugin then
        return
      end

      section_values.plugin = nil

      -- 遍历并设置映射
      for mode, mode_values in pairs(section_values) do

        -- default_opts 为 {mode = mode}表和mapping_opt表的合并，因为设置为force，所以，若键名相同，后者数值替换前者数值。
        -- 这样确保了如果用户提供了额外的选项，这些选项会覆盖默认设置中相同的键。
        local default_opts = merge_tb("force", { mode = mode }, mapping_opt or {})

        -- 示例：["<C-b>"] = { "<ESC>^i", "Beginning of line" }
        -- keybind: "<C-b>"
        -- mapping_info[0]: "<ESC>^i"
        -- mapping_info[1]: "Beginning of line"
        for keybind, mapping_info in pairs(mode_values) do
          -- merge default + user opts
          -- 合并表，mapping_info.opts的键值会替换default_opts中的键值
          local opts = merge_tb("force", default_opts, mapping_info.opts or {})

          mapping_info.opts, opts.mode = nil, nil
          opts.desc = mapping_info[2]

          -- vim.keymap.set()用户设置键位映射
          -- mode指定了映射的模式
          -- keybind是键位
          -- mapping_info[1]是实际的指令
          -- opts：映射的额外选项
          -- opts.desc是快捷键的描述信息
          -- 这里是实际设置vim快捷键的地方
          vim.keymap.set(mode, keybind, mapping_info[1], opts)
        end
      end
    end

    -- mappings来源于两个文件：
    -- 1. lua/core/mappings.lua
    -- 2. custom/mappings.lua (如果存在的话)
    -- 拿到合并后的系统配置中的mappings
    local mappings = require("core.utils").load_config().mappings

    -- 后面的部分没有看，后面结合实际调用功能去看
    -- 在init.lua中被调用的时候，没有传入任何参数，因此，这里的代码应该是要被忽略掉的
    if type(section) == "string" then
      mappings[section]["plugin"] = nil
      -- section为给定字符串时，mappings为局部内容。
      -- 否则，就是全部内容。
      mappings = { mappings[section] }
    end

    for _, sect in pairs(mappings) do
      set_section_map(sect)
    end
  end) -- END: vim.schedule()
end

M.lazy_load = function(plugin)
  vim.api.nvim_create_autocmd({ "BufRead", "BufWinEnter", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("BeLazyOnFileOpen" .. plugin, {}),
    callback = function()
      local file = vim.fn.expand "%"
      local condition = file ~= "NvimTree_1" and file ~= "[lazy]" and file ~= ""

      if condition then
        vim.api.nvim_del_augroup_by_name("BeLazyOnFileOpen" .. plugin)

        -- dont defer for treesitter as it will show slow highlighting
        -- This deferring only happens only when we do "nvim filename"
        if plugin ~= "nvim-treesitter" then
          vim.schedule(function()
            require("lazy").load { plugins = plugin }

            if plugin == "nvim-lspconfig" then
              vim.cmd "silent! do FileType"
            end
          end, 0)
        else
          require("lazy").load { plugins = plugin }
        end
      end
    end,
  })
end

return M
