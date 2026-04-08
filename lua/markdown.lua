-- ~/.config/nvim/lua/markdown.lua
local M = {}

-- =============================
-- 获取合法 URL（剪贴板）
-- =============================
local function get_clipboard_url()
  local clip = vim.fn.getreg("+")
  if clip:match("^https?://") or clip:match("^/") then
    return clip
  end
  return ""
end

-- =============================
-- 尝试修改已有链接
-- =============================
local function try_update_existing_link()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  local line = vim.api.nvim_buf_get_lines(0, row, row+1, false)[1]
  local s, e, text, url = line:find("%[([^%]]+)%]%(([^%)]+)%)")
  if not s then return false end
  if col < s-1 or col > e then return false end
  local new_url = vim.fn.input("修改 URL: ", url)
  if new_url == "" then return true end
  local new_link = string.format("[%s](%s){:target=\"_blank\"}", text, new_url)
  vim.api.nvim_buf_set_text(0, row, s-1, row, e, {new_link})
  vim.api.nvim_win_set_cursor(0, {row+1, s + #text + 2})
  return true
end

-- =============================
-- 插入链接核心函数
-- =============================
function M.insert_link()
  local mode = vim.fn.mode()
  local bufnr = 0

  -- 尝试修改已有链接
  if mode == "n" and try_update_existing_link() then return end

  -- =========================
  -- VISUAL 模式
  -- =========================
  if mode:match("[vV ]") then
    vim.cmd("normal! gv") -- 恢复选区
    local start = vim.api.nvim_buf_get_mark(0, "<")
    local finish = vim.api.nvim_buf_get_mark(0, ">")
    local srow, scol = start[1]-1, start[2]
    local erow, ecol = finish[1]-1, finish[2]

    -- 获取选中文本
    local lines = vim.api.nvim_buf_get_text(bufnr, srow, scol, erow, ecol, {})
    if #lines == 0 then
      vim.notify("未选中内容", vim.log.levels.ERROR)
      return
    end

    local url = vim.fn.input("URL: ", get_clipboard_url())
    if url == "" then return end

    if #lines == 1 then
      local link = string.format("[%s](%s){:target=\"_blank\"}", lines[1], url)
      vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, {link})
      vim.api.nvim_win_set_cursor(0, {srow+1, scol + #lines[1] + 2})
    else
      for i, line in ipairs(lines) do
        lines[i] = string.format("[%s](%s){:target=\"_blank\"}", line, url)
      end
      vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, lines)
    end

    -- 退出 Visual 模式
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    return
  end

  -- =========================
  -- NORMAL 模式
  -- =========================
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1

  -- 获取光标所在单词
  local word = vim.fn.expand("<cword>")
  local text = vim.fn.input("文本: ", word)
  if text == "" then return end

  local url = vim.fn.input("URL: ", get_clipboard_url())
  if url == "" then return end

  local link = string.format("[%s](%s){:target=\"_blank\"}", text, url)
  vim.api.nvim_buf_set_text(bufnr, row, col, row, col, {link})
  vim.api.nvim_win_set_cursor(0, {row+1, col + vim.str_byteindex(link, #text)})
end

-- =============================
-- keymap
-- =============================
vim.keymap.set("n", "<leader>m", function()
  require("markdown").insert_link()
end, { noremap = true })

vim.keymap.set("v", "<leader>m", function()
  require("markdown").insert_link()
end, { noremap = true })

-- =============================
-- UTF-8 保证
-- =============================
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = {"*.md", "*.markdown"},
  callback = function()
    vim.opt_local.fileencoding = "utf-8"
  end,
})

-- =============================
-- reload
-- =============================
vim.api.nvim_create_user_command("ReloadMarkdown", function()
  package.loaded["markdown"] = nil
  require("markdown")
  print("Markdown.lua 已重新加载")
end, {})

return M
