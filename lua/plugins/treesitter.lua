return {
  "romus204/tree-sitter-manager.nvim",
  -- tree-sitter CLI must be installed system-wide:
  -- npm install -g tree-sitter-cli
  dependencies = {},
  config = function()
    require("tree-sitter-manager").setup({
      -- Default Options
      ensure_installed = {
        'python',
        'bash',
        'c',
        'c_sharp',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
        'css',
        'rust',
        'sql',
        'go',
        'nginx',
        'regex',
        'tmux',
        'tsx',
        'typescript',
        'yaml',
        'zsh'
      },
      border = "rounded", -- border style for the window (e.g. "rounded", "single"), if nil, use the default border style defined by 'vim.o.winborder'. See :h 'winborder' for more info.
      auto_install = false, -- if enabled, install missing parsers when editing a new file
      -- languages = {}, -- override or add new parser sources
    })
  end
}
