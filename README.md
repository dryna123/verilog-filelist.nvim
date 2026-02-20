# verilog-filelist
用于处理 Verilog filelist 并生成 ctags 的 Neovim 插件
## Features
- Resolve nested `-f` references in Verilog filelists
- Expand environment variables (e.g. `$HOME`, `${WORK_DIR}`)
- Deduplicate file paths
- Generate ctags for all flattened files
- Debug mode for troubleshooting

## Requirements
- Neovim >= 0.9
- `ctags` (with Verilog/SystemVerilog support)
- Lazy.nvim (or other package managers)

## Installation
### Lazy.nvim
```lua
{
  "你的GitHub用户名/verilog-filelist.nvim",
  lazy = false, -- 或按需加载
  config = function()
    -- 可选：自定义配置
    require("verilog_filelist").setup({
      debug = false,
      default_output = "flattened_filelist",
    })
  end,
}
