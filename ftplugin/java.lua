local jdtls = require 'jdtls'

-- Determine workspace directory
local home = os.getenv 'HOME'

-- Skip starting JDTLS for virtual/decompiled buffers (e.g., jdt://, jar:) or non-file buffers
local bufname = vim.api.nvim_buf_get_name(0)
if bufname:match '^jdt://' or bufname:match '^jar:' or vim.bo.buftype ~= '' then
  return
end

-- Prefer Git root for multi-module projects, else fall back to Maven/Gradle markers
local git_root = require('jdtls.setup').find_root { '.git' }
local root_dir = git_root or require('jdtls.setup').find_root { 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' }
if not root_dir or root_dir == '' then
  vim.notify('jdtls: could not find project root', vim.log.levels.WARN)
  return
end
local project_name = vim.fn.fnamemodify(root_dir, ':p:h:t')
local workspace_path = vim.fn.stdpath 'data' .. '/jdtls/' .. project_name .. '_' .. vim.fn.sha256(root_dir):sub(1, 8)
-- Resolve Java runtimes on macOS via java_home; fall back to $JAVA_HOME or 'java' on PATH
local function try_java_home(version)
  local out = vim.fn.system('/usr/libexec/java_home -v ' .. version):gsub('%s+$', '')
  if out ~= '' then
    return out
  end
end

local java_homes = {}
for _, v in ipairs { '24', '21', '17' } do
  local p = try_java_home(v)
  if p and p ~= '' then
    table.insert(java_homes, { name = 'JavaSE-' .. v, path = p })
  end
end

local java_from_env = os.getenv 'JAVA_HOME'
local chosen_java_home = java_homes[1] and java_homes[1].path or ((java_from_env and java_from_env ~= '') and java_from_env or nil)
local java_cmd = (chosen_java_home and (chosen_java_home .. '/bin/java')) or 'java'

-- Find the jdtls installation
local mason_path = vim.fn.stdpath 'data' .. '/mason'
local jdtls_path = mason_path .. '/packages/jdtls'
local launcher_jar = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')

if launcher_jar == '' then
  vim.notify('jdtls launcher jar not found', vim.log.levels.ERROR)
  return
end
if launcher_jar:find '\n' then
  launcher_jar = vim.split(launcher_jar, '\n')[1]
end

-- Determine JDTLS platform config directory
local sysname = (vim.uv or vim.loop).os_uname().sysname
local config_dir = 'config_mac'
if sysname == 'Linux' then
  config_dir = 'config_linux'
elseif sysname:match 'Windows' then
  config_dir = 'config_win'
end

local config = {
  cmd = {
    java_cmd,
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=WARN',
    '-Xms1g',
    '--add-opens',
    'java.base/java.util=ALL-UNNAMED',
    '--add-opens',
    'java.base/java.lang=ALL-UNNAMED',
    '-jar',
    launcher_jar,
    '-configuration',
    jdtls_path .. '/' .. config_dir,
    '-data',
    workspace_path,
  },

  cmd_env = chosen_java_home and { JAVA_HOME = chosen_java_home } or nil,

  root_dir = root_dir,

  settings = {
    java = {
      eclipse = {
        downloadSources = true,
      },
      configuration = {
        updateBuildConfiguration = 'automatic',
        runtimes = java_homes,
      },
      maven = {
        downloadSources = true,
      },
      implementationsCodeLens = {
        enabled = true,
      },
      referencesCodeLens = {
        enabled = true,
      },
      references = {
        includeDecompiledSources = true,
      },
      format = {
        enabled = true,
      },
      project = {
        referencedLibraries = {
          'lib/**/*.jar',
          'target/dependency/*.jar',
        },
      },
    },
  },

  init_options = {
    bundles = {},
  },

  on_attach = function(client, bufnr)
    -- Enable completion triggered by <c-x><c-o>
    vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Java-specific keymaps
    local opts = { noremap = true, silent = true, buffer = bufnr }
    vim.keymap.set('n', '<leader>co', '<cmd>lua require("jdtls").organize_imports()<CR>', vim.tbl_extend('force', opts, { desc = 'Organize imports' }))
    vim.keymap.set('n', '<leader>cv', '<cmd>lua require("jdtls").extract_variable()<CR>', vim.tbl_extend('force', opts, { desc = 'Extract variable' }))
    vim.keymap.set('v', '<leader>cv', '<cmd>lua require("jdtls").extract_variable(true)<CR>', vim.tbl_extend('force', opts, { desc = 'Extract variable' }))
    vim.keymap.set('n', '<leader>cc', '<cmd>lua require("jdtls").extract_constant()<CR>', vim.tbl_extend('force', opts, { desc = 'Extract constant' }))
    vim.keymap.set('v', '<leader>cc', '<cmd>lua require("jdtls").extract_constant(true)<CR>', vim.tbl_extend('force', opts, { desc = 'Extract constant' }))
    vim.keymap.set('v', '<leader>cm', '<cmd>lua require("jdtls").extract_method(true)<CR>', vim.tbl_extend('force', opts, { desc = 'Extract method' }))
  end,
}

jdtls.start_or_attach(config)
