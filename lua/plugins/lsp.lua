-- :Mason for graphical status window

return {
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    -- event = { "BufReadPre", "BufNewFile" }, -- load on file/buffer open
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      { 'williamboman/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
      { 'williamboman/mason-lspconfig.nvim', version = '1.32.0'},
      {'WhoIsSethDaniel/mason-tool-installer.nvim', commit = '1255518cb067e038a4755f5cb3e980f79b6ab89c'},
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by nvim-cmp
      'hrsh7th/cmp-nvim-lsp',

      -- Language Specific:
    },
    config = function()
      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end
          local telescope_builtin = require('telescope.builtin')

          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-t>.
          map('gd', telescope_builtin.lsp_definitions, '[G]oto [D]efinition')

          -- Find references for the word under your cursor.
          map('gr', telescope_builtin.lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          --  Useful when your language has ways of declaring types without an actual implementation.
          map('gI', telescope_builtin.lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('<leader>D', telescope_builtin.lsp_type_definitions, 'Type [D]efinition')

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          map('<leader>gs', telescope_builtin.lsp_document_symbols, '[D]ocument [S]ymbols')

          -- Fuzzy find all the symbols in your current workspace.
          --  Similar to document symbols, except searches over your entire project.
          map('<leader>ws', telescope_builtin.lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })

          -- Go to declaration (not definition)
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      -- Enable the following language servers
      local function get_python_path()
        local cwd = vim.fn.getcwd()

        -- Check local virtual environments first
        for _, name in ipairs({ ".venv", "venv", ".env", "env" }) do
          local path = cwd .. "/" .. name .. "/bin/python"
          if vim.fn.executable(path) == 1 then
            return path
          end
        end

        -- Try Poetry environment
        local poetry_env_path = vim.fn.trim(vim.fn.system("poetry env info -p 2>/dev/null"))
        if vim.v.shell_error == 0 then
          local poetry_python = poetry_env_path .. "/bin/python"
          if vim.fn.executable(poetry_python) == 1 then
            return poetry_python
          end
        end

        -- Fallback to system Python
        return vim.fn.exepath("python3") or "python3"
      end

      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = true,
      })

      local servers = {
        basedpyright = {
          enabled = true,
          capabilities = capabilities,
          settings = {
            pythonPath = get_python_path(),
            basedpyright = {
              analysis = {
                typeCheckingMode = "basic",
                diagnosticMode = "openFilesOnly",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                autoImportCompletions = true,
              }
            }
          }
        },
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              workspace = {
                maxPreload = 10000,
                preloadFileSize = 1000,
              },
            },
          },
        },
        -- sqlls = {},
        rust_analyzer = {
          settings = {
            ['rust_analyzer'] = {
              diagnostics = {
                enable = false;
              }
            }
          }
        }
      }

      -- Ensure the servers and tools above are installed
      --  To check the current status of installed tools and/or manually install
      --  other tools, you can run
      --    :Mason
      require('mason').setup()
      local ensure_installed = vim.tbl_keys(servers or {})

      vim.list_extend(ensure_installed, {
        'stylua', -- Lua language
        'basedpyright', -- Python language 
        'debugpy',
        -- 'sqlls'
      })
      require('mason-tool-installer').setup{ ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {
          'basedpyright',
          'lua_ls',
          'rust_analyzer'
        },
        automatic_installation = true,
        automatic_enable = true,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            vim.lsp.config(server_name, server)
            vim.lsp.enable(server_name)
          end,
        },
      }

      -- Ignore certain errors (beyond LSP coverage)
      vim.lsp.handlers["textDocument/publishDiagnostics"] = function(_, result, ctx, config)
        local filtered_diagnostics = {}

        local errors_to_ignore = {
          'Function declaration "step_impl" is obscured by a declaration of the same name',
          'Function declaration "step" is obscured by a declaration of the same name'
        }

        -- Helper function to check if a message is in the ignore list
        local function should_ignore(message)
          for _, error_message in ipairs(errors_to_ignore) do
            if message == error_message then
              return true
            end
          end
          return false
        end

        -- Filter diagnostics
        for _, diagnostic in ipairs(result.diagnostics) do
          if not should_ignore(diagnostic.message) then
            table.insert(filtered_diagnostics, diagnostic)
          end
        end

        result.diagnostics = filtered_diagnostics
        vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
      end
    end,

    -- Retool
    vim.filetype.add({
      extension = {
        rsx = "javascriptreact",
      },
    })
  },
}

