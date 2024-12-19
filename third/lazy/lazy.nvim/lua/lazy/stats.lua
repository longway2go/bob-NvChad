--------------------------------------------------------------------
--- lazy/stats.lua
--- 定义了lazy.nvim的LazyStats模块，用于跟踪和报告与插件加载相关的性能统计信息。
--------------------------------------------------------------------

-- 引入ffi库，用于与C库交互。
local ffi = require("ffi")

-- 创建一个本地表M，用于存储模块的函数和数据
local M = {}

-- 注释文档，表明M是LazyStats类
---@class LazyStats
-- 在M中定义一个表_stats，用于存储性能数据
M._stats = {
  -- startuptime in milliseconds till UIEnter
  -- Neovim到达UI所花费的时间（以毫秒为单位）
  startuptime = 0,
  -- when true, startuptime is the accurate cputime for the Neovim process. (Linux & macOS)
  -- this is more accurate than `nvim --startuptime`, and as such will be slightly higher
  -- when false, startuptime is calculated based on a delta with a timestamp when lazy started.
  -- 布尔值，指示startuptime是否为实际CPU时间
  real_cputime = false,
  -- 配置的插件总数
  count = 0, -- total number of plugins
  -- 成功加载的插件数
  loaded = 0, -- number of loaded plugins
  ---@type table<string, number>
  -- 一个表，存储启动过程中各种事件的时间戳
  times = {},
}

---@type ffi.namespace*
M.C = nil

-- on_ui_enter(): 在Neovim进入UI模块时触发
function M.on_ui_enter()
  -- 记录当前的CPU时间，存储在M._stats.startuptime中
  M._stats.startuptime = M.track("UIEnter")

  -- 将启动时间发送到单独的跟踪系统
  require("lazy.core.util").track({ start = "startuptime" }, M._stats.startuptime * 1e6)

  -- 触发模式为"LazyVimStarted"的用户自定义Neovim自动命令
  vim.api.nvim_exec_autocmds("User", { pattern = "LazyVimStarted", modeline = false })
end

-- track(): 
-- 接受一个事件名称，并使用M.cputime()记录当前的CPU时间。
-- 将该CPU时间存储在M._stats.times表中，键名为提供的事件名称。
function M.track(event)
  local time = M.cputime()
  M._stats.times[event] = time
  return time
end

-- cputime(): CPU时间测量
function M.cputime()
  -- 检查是否已建立C库连接(M.c)。
  -- 如果没有，则尝试使用ffi.cdef进行连接，并定义并要的结构和函数。
  if M.C == nil then
    pcall(function()
      ffi.cdef([[
        typedef long time_t;
        typedef int clockid_t;
        typedef struct timespec {
          time_t   tv_sec;        /* seconds */
          long     tv_nsec;       /* nanoseconds */
        } nanotime;
        int clock_gettime(clockid_t clk_id, struct timespec *tp);
      ]])
      M.C = ffi.C
    end)
  end

  -- real(): 使用clock_gettime检索实际的CPU时间
  -- 作为首选计算CPU的接口函数
  local function real()
    local pnano = assert(ffi.new("nanotime[?]", 1))
    local CLOCK_PROCESS_CPUTIME_ID = jit.os == "OSX" and 12 or 2
    ffi.C.clock_gettime(CLOCK_PROCESS_CPUTIME_ID, pnano)
    return tonumber(pnano[0].tv_sec) * 1e3 + tonumber(pnano[0].tv_nsec) / 1e6
  end

  -- 根据lazy.nvim启动以来的时间差和vim.uv的当前高分辨率时间计算近似的CPU时间
  -- 作为备选，计算CPU的接口函数
  local function fallback()
    return (vim.uv.hrtime() - require("lazy")._start) / 1e6
  end

  -- 尝试调用real()。
  -- 如果成功，将M.cputime设置为检索到的时间，并将_stats.real_cputime标记为true。
  -- 否则，回退到fallback()并相应地更新M.cputime。
  local ok, ret = pcall(real)
  if ok then
    M.cputime = real
    M._stats.real_cputime = true
    return ret
  else
    M.cputime = fallback
    return fallback()
  end
end

-- stats(): 报告统计信息
function M.stats()
  M._stats.count = 0
  M._stats.loaded = 0

  -- 遍历lazy.core.config管理的所有插件。
  for _, plugin in pairs(require("lazy.core.config").plugins) do
    M._stats.count = M._stats.count + 1 -- 使用插件总数更新_stats.count

    -- 对每个插件，使用_.loaded属性检查是否已加载。如果已加载，则递增_stats.loaded。
    if plugin._.loaded then
      M._stats.loaded = M._stats.loaded + 1
    end
  end

  -- 返回包含插件加载统计信息的更新后的_stats表。
  return M._stats
end

return M
