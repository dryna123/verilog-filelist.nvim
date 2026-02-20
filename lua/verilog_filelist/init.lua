local M = {}

-- 全局配置（默认值）
M.config = {
  verilog_ctags_output_dir = "",
  debug = false,
  default_output = "flattened_filelist",
}

-- 1. 调试打印函数（原代码）
local function debug_print(msg, prefix)
  if not M.config.debug then return end
  local p = prefix or "DEBUG"
  local final_msg = type(msg) == "string" and msg or tostring(msg)
  vim.notify(string.format("[%s] %s", p, final_msg), vim.log.levels.DEBUG)
end

-- 2. 环境变量解析（原代码）
local function resolve_vars(path)
  if not path or path == "" then return path end
  path = path:gsub("%${([%w_]+)}", function(var)
    local val = os.getenv(var)
    if not val or val == "" then
      vim.notify("警告：环境变量 $" .. var .. " 未定义", vim.log.levels.WARN)
      return "$" .. var
    end
    return val
  end)
  path = path:gsub("%$([%w_]+)", function(var)
    if var == "" then return "$" end
    local val = os.getenv(var)
    if not val or val == "" then
      vim.notify("警告：环境变量 $" .. var .. " 未定义", vim.log.levels.WARN)
      return "$" .. var
    end
    return val
  end)
  return path
end

-- 3. 路径标准化（原代码）
local function normalize_path(path, base_dir)
  if not path or path == "" then return "" end
  local resolved = resolve_vars(path)
  if resolved:match "^%$" then
    vim.notify("警告：路径包含未解析的环境变量 - " .. resolved, vim.log.levels.WARN)
    return ""
  end
  local is_abs = resolved:match "^/" or resolved:match "^%a:[/\\]"
  if not is_abs then
    if not base_dir or base_dir == "" then
      debug_print("基础目录无效，无法拼接相对路径：" .. resolved, "路径处理")
      return ""
    end
    resolved = vim.fn.fnamemodify(base_dir .. "/" .. resolved, ":p")
  else
    resolved = vim.fn.fnamemodify(resolved, ":p")
  end
  resolved = vim.fn.simplify(resolved)
  return resolved
end

-- 4. 递归处理 filelist（原代码）
local function process_file(file_path, visited, flattened, top_file_dir)
  debug_print(string.rep("=", 50), "开始处理文件")
  debug_print("原始输入路径：" .. file_path)

  local resolved_path = normalize_path(file_path, top_file_dir)
  debug_print("变量展开+标准化后路径：" .. (resolved_path or "空路径"))

  if not resolved_path or resolved_path == "" or visited[resolved_path] then
    debug_print("文件已处理/路径无效，跳过：" .. (resolved_path or "空路径"), "跳过")
    debug_print(string.rep("-", 50))
    return
  end
  visited[resolved_path] = true

  if not vim.fn.filereadable(resolved_path) then
    vim.notify("警告：文件不存在或无法读取 - " .. resolved_path, vim.log.levels.WARN)
    debug_print("文件不可读，跳过", "警告")
    debug_print(string.rep("-", 50))
    return
  end
  debug_print("文件可读，开始解析内容", "成功")

  local lines = vim.fn.readfile(resolved_path, "b") or {}
  debug_print("文件共 " .. #lines .. " 行")

  local current_file_dir = vim.fn.fnamemodify(resolved_path, ":h")
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line or "")
    debug_print('原始行："' .. trimmed .. '"', "行处理")
    if trimmed == "" then
      debug_print("空行，跳过", "行处理")
      debug_print(string.rep("-", 30), "行处理结束")
    elseif trimmed:match "^%s*//" then
      debug_print("整行注释，跳过", "行处理")
      debug_print(string.rep("-", 30), "行处理结束")
    else
      local clean_line = trimmed:gsub("%s*//.*$", "")
      if clean_line == "" then
        debug_print("行内注释后为空，跳过", "行处理")
        debug_print(string.rep("-", 30), "行处理结束")
      else
        debug_print('去除注释后："' .. clean_line .. '"', "行处理")

        if clean_line:match "^%s*-f%s+" then
          local nested_file = vim.trim(clean_line:gsub("^%s*-f%s+", ""))
          debug_print("发现 -f 嵌套引用：" .. nested_file, "嵌套")
          process_file(nested_file, visited, flattened, current_file_dir)
        else
          local resolved_line = normalize_path(clean_line, current_file_dir)
          if resolved_line and resolved_line ~= "" then
            debug_print("普通文件标准化后：" .. resolved_line, "行处理")
            table.insert(flattened, resolved_line)
            debug_print(
              "添加到结果列表（当前总数：" .. #flattened .. "）",
              "行处理"
            )
          else
            debug_print(
              "普通文件路径解析失败/包含未定义变量，跳过：" .. clean_line,
              "行处理"
            )
          end
        end
        debug_print(string.rep("-", 30), "行处理结束")
      end
    end
  end

  debug_print("文件处理完成：" .. resolved_path, "结束")
  debug_print(string.rep("=", 50))
end

-- 5. 生成 tags 文件（原代码）
local function generate_tags(flattened_file)
  if not M.config.verilog_ctags_output_dir or M.config.verilog_ctags_output_dir == "" then
    vim.notify("错误：无法获取当前 filelist 文件的上级目录", vim.log.levels.ERROR)
    return false
  end

  local tags_dir = resolve_vars(M.config.verilog_ctags_output_dir)
  local tags_file = tags_dir .. "/tags"

  if not flattened_file or not vim.fn.filereadable(flattened_file) then
    vim.notify(
      "错误：展平后的 filelist 文件不存在 - " .. (flattened_file or "空路径"),
      vim.log.levels.ERROR
    )
    return false
  end

  if not vim.fn.isdirectory(tags_dir) then
    debug_print("tags 目录不存在，创建：" .. tags_dir, "TAGS")
    local mkdir_cmd = string.format("mkdir -p %s", vim.fn.shellescape(tags_dir))
    local mkdir_result = vim.fn.system(mkdir_cmd)
    if vim.v.shell_error ~= 0 then
      vim.notify(
        "错误：创建 tags 目录失败 - " .. tags_dir .. "\n" .. mkdir_result,
        vim.log.levels.ERROR
      )
      return false
    end
  end

  local escaped_tags = vim.fn.shellescape(tags_file)
  local escaped_flist = vim.fn.shellescape(flattened_file)
  local ctags_cmd = string.format(
    "ctags --verbose --languages=Verilog,SystemVerilog -f %s -L %s",
    escaped_tags,
    escaped_flist
  )

  debug_print("执行 ctags 命令：" .. ctags_cmd, "TAGS")
  local ctags_result = vim.fn.system(ctags_cmd)
  if vim.v.shell_error == 0 then
    vim.notify("成功生成 tags 文件：" .. tags_file, vim.log.levels.INFO)
    debug_print("tags 生成成功：" .. ctags_result, "TAGS")
    return true
  else
    vim.notify(
      "错误：生成 tags 失败\n命令：" .. ctags_cmd .. "\n错误：" .. ctags_result,
      vim.log.levels.ERROR
    )
    return false
  end
end

-- 6. 去重（原代码）
local function deduplicate(list)
  local temp = {}
  local result = {}
  for _, path in ipairs(list or {}) do
    if path and path ~= "" and not temp[path] then
      temp[path] = true
      table.insert(result, path)
    else
      debug_print("重复/无效文件，跳过：" .. (path or "空路径"), "去重")
    end
  end
  return result
end

-- 7. 核心导出函数（原代码）
function M.flatten_verilog_filelist(args)
  local output = M.config.default_output
  if args and #args > 0 and args[1] ~= "" then output = args[1] end

  local current_file = vim.fn.expand "%:p"
  if current_file == "" then
    vim.notify("错误：请先打开一个顶层 filelist 文件", vim.log.levels.ERROR)
    return
  end

  local current_file_parent_dir = vim.fn.expand "%:p:h:h"
  M.config.verilog_ctags_output_dir = current_file_parent_dir
  debug_print("当前 filelist 上级目录：" .. current_file_parent_dir, "路径配置")

  debug_print(string.rep("=", 60), "顶层处理开始")
  debug_print("顶层文件：" .. current_file)

  local visited = {}
  local flattened = {}
  local top_file_dir = vim.fn.fnamemodify(current_file, ":h")

  process_file(current_file, visited, flattened, top_file_dir)

  local original_len = #flattened
  local flattened_unique = deduplicate(flattened)
  debug_print(
    string.format("去重前：%d 个，去重后：%d 个", original_len, #flattened_unique),
    "去重"
  )

  vim.fn.writefile(flattened_unique, output, "b")
  local output_full = vim.fn.fnamemodify(output, ":p")

  vim.notify(
    string.format(
      "成功展平 filelist！\n输入：%s\n输出：%s\n总数：%d（去重前 %d）\ntags 目录：%s",
      current_file,
      output_full,
      #flattened_unique,
      original_len,
      current_file_parent_dir
    ),
    vim.log.levels.INFO
  )
  debug_print(string.rep("=", 60), "filelist 展平完成")

  debug_print(string.rep("=", 60), "开始生成 tags")
  generate_tags(output_full)

  debug_print(string.rep("=", 60), "全部处理完成")
end

-- 配置覆盖函数（可选，方便用户自定义配置）
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

return M
