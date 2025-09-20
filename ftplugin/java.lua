local jdtls = require 'jdtls'

-- Determine workspace directory
local home = os.getenv 'HOME'

-- Skip starting JDTLS for virtual/decompiled buffers (e.g., jdt://, jar:) or non-file buffers
local bufname = vim.api.nvim_buf_get_name(0)
if bufname:match('^jdt://') or bufname:match('^jar:') or vim.bo.buftype ~= '' then
  return
end

-- Prefer Git root for multi-module projects, else fall back to Maven/Gradle markers
local git_root = require('jdtls.setup').find_root { '.git' }
local root_dir = git_root or require('jdtls.setup').find_root { 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' }
if not root_dir or root_dir == '' then
  vim.notify('jdtls: could not find project root', vim.log.levels.ERROR)
  return
end
local project_name = vim.fn.fnamemodify(root_dir, ':p:h:t')
local workspace_path = vim.fn.stdpath('data') .. '/jdtls/' .. project_name .. '_' .. vim.fn.sha256(root_dir):sub(1, 8)
-- Resolve JDK 24 via macOS java_home
local java_home_24 = vim.fn.system('/usr/libexec/java_home -v 24'):gsub('%s+$', '')
if java_home_24 == '' then
  vim.notify('jdtls: JDK 24 not found. Install it or adjust java_home resolution.', vim.log.levels.ERROR)
  return
end

-- Find the jdtls installation
local mason_path = vim.fn.stdpath 'data' .. '/mason'
local jdtls_path = mason_path .. '/packages/jdtls'
local launcher_jar = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')

if launcher_jar == '' then
  vim.notify('jdtls launcher jar not found', vim.log.levels.ERROR)
  return
end

local config = {
  cmd = {
    java_home_24 .. '/bin/java',
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=ALL',
    '-Xms1g',
    '--add-opens',
    'java.base/java.util=ALL-UNNAMED',
    '--add-opens',
    'java.base/java.lang=ALL-UNNAMED',
    '-jar',
    launcher_jar,
    '-configuration',
    jdtls_path .. '/config_mac_arm',
    '-data',
    workspace_path,
  },

  root_dir = root_dir,

  settings = {
    java = {
      eclipse = {
        downloadSources = true,
      },
      configuration = {
        updateBuildConfiguration = 'automatic',
        runtimes = {
          {
            name = 'JavaSE-24',
            path = java_home_24,
          },
          {
            name = 'JavaSE-21',
            path = '/Library/Java/JavaVirtualMachines/liberica-jdk-21-full.jdk/Contents/Home',
          },
          {
            name = 'JavaSE-17',
            path = '/Library/Java/JavaVirtualMachines/liberica-jdk-17-full.jdk/Contents/Home',
          },
        },
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
