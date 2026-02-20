-- 加载核心模块并初始化
local ok, verilog_filelist = pcall(require, "verilog_filelist")
if not ok then
  vim.notify("Failed to load verilog-filelist.nvim: " .. verilog_filelist, vim.log.levels.ERROR)
  return
end

-- 注册用户命令（原代码中的 nvim_create_user_command）
vim.api.nvim_create_user_command(
  "VerilogFilelist",
  function(opts) verilog_filelist.flatten_verilog_filelist(opts.fargs) end,
  {
    nargs = "?",
    complete = "file",
    desc = "Flatten Verilog filelist and generate ctags for Verilog/SystemVerilog",
  }
)
