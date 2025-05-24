local cmp = require 'cmp'
local Job = require 'plenary.job'

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

function source:is_available()
  return false
end

function source:complete(params, callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local line = params.context.cursor.row -- This is a number (1-based)
  local start_line = math.max(0, line - 50) -- Lua indices are 1-based, but nvim_buf_get_lines is 0-based
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, line - 1, false)
  local prompt = table.concat(lines, '\n')

  if not prompt or #prompt < 5 then
    callback { { label = 'Type more code for GPT-4 completion', kind = cmp.lsp.CompletionItemKind.Text } }
    return
  end

  local api_key = os.getenv 'OPENAI_API_KEY'
  if not api_key then
    callback { { label = 'No OPENAI_API_KEY set', kind = cmp.lsp.CompletionItemKind.Text } }
    return
  end

  local data = vim.fn.json_encode {
    model = 'gpt-4.1', -- or your available GPT-4.1 model
    messages = {
      {
        role = 'system',
        content = 'You are a code completion engine. Only output the next lines of code, never explanations, comments, or markdown formatting.',
      },
      { role = 'user', content = prompt },
    },
    max_tokens = 256,
    temperature = 0.2,
  }

  Job:new({
    command = 'curl',
    args = {
      '-s',
      '-X',
      'POST',
      '-H',
      'Content-Type: application/json',
      '-H',
      'Authorization: Bearer ' .. api_key,
      '-d',
      data,
      'https://api.openai.com/v1/chat/completions',
    },
    on_exit = function(j, return_val)
      local result = table.concat(j:result(), '\n')
      local ok, decoded = pcall(vim.json.decode, result)
      if ok and decoded then
        if decoded.error then
          print('GPT-4 API error: ' .. decoded.error.message)
          callback {
            { label = 'GPT-4.1 error: ' .. decoded.error.message, kind = cmp.lsp.CompletionItemKind.Text },
          }
        elseif decoded.choices and decoded.choices[1] then
          local text = decoded.choices[1].message.content
          callback {
            { label = text, kind = cmp.lsp.CompletionItemKind.Text },
          }
        else
          print('GPT-4 API: Unexpected response: ' .. result)
          callback {
            { label = 'GPT-4.1 error or no response', kind = cmp.lsp.CompletionItemKind.Text },
          }
        end
      else
        print('GPT-4 API: Could not decode response: ' .. result)
        callback {
          { label = 'GPT-4.1 error or no response', kind = cmp.lsp.CompletionItemKind.Text },
        }
      end
    end,
  }):start()
end

return source
