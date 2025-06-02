local jdtls = require 'jdtls'

-- Determine workspace directory
local home = os.getenv 'HOME'
local workspace_path = home .. '/.local/share/eclipse/' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')

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
    'java',
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=ALL',
    '-Xms1g',
    '--add-modules=ALL-SYSTEM',
    '--add-opens',
    'java.base/java.util=ALL-UNNAMED',
    '--add-opens',
    'java.base/java.lang=ALL-UNNAMED',
    '--enable-native-access=ALL-UNNAMED',
    '-jar',
    launcher_jar,
    '-configuration',
    jdtls_path .. '/config_mac',
    '-data',
    workspace_path,
  },

  root_dir = require('jdtls.setup').find_root { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' },

  settings = {
    java = {
      eclipse = {
        downloadSources = true,
      },
      configuration = {
        updateBuildConfiguration = 'interactive',
        runtimes = {
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
