-- ============================================================
-- Options
-- ============================================================
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"   -- always show, prevents layout shifting

-- ============================================================
-- Keymaps
-- ============================================================
vim.g.mapleader = " "

local map = vim.keymap.set
map("n", "<leader>e", vim.diagnostic.open_float)
map("n", "[d",        vim.diagnostic.goto_prev)
map("n", "]d",        vim.diagnostic.goto_next)

-- ============================================================
-- LSP
-- ============================================================
local lspconfig = require("lspconfig")

-- Shared on_attach: only maps keys after LSP attaches to buffer
local on_attach = function(_, bufnr)
  local opts = { buffer = bufnr }
  map("n", "gd",         vim.lsp.buf.definition,      opts)
  map("n", "K",          vim.lsp.buf.hover,            opts)
  map("n", "<leader>rn", vim.lsp.buf.rename,           opts)
  map("n", "<leader>ca", vim.lsp.buf.code_action,      opts)
  map("n", "<leader>f",  vim.lsp.buf.format,           opts)
end

-- ============================================================
-- File Explorer (nvim-tree)
-- ============================================================
require("nvim-tree").setup({
  view = { width = 30 },
  renderer = { group_empty = true },
  filters = { dotfiles = false },  -- show dotfiles
})

map("n", "<leader>e", ":NvimTreeToggle<CR>")   -- toggle explorer
map("n", "<leader>o", ":NvimTreeFocus<CR>")    -- focus explorer

-- ============================================================
-- Fuzzy Finder (telescope)
-- ============================================================
local telescope = require("telescope.builtin")

map("n", "<C-p>",      telescope.find_files)   -- exactly like VSCode
map("n", "<leader>fg", telescope.live_grep)    -- search inside files
map("n", "<leader>fb", telescope.buffers)      -- open buffers
map("n", "<leader>fh", telescope.help_tags)

-- ============================================================
-- Git signs (gutter indicators like VSCode)
-- ============================================================
require("gitsigns").setup({
  signs = {
    add          = { text = "▎" },
    change       = { text = "▎" },
    delete       = { text = "▎" },
    topdelete    = { text = "▎" },
    changedelete = { text = "▎" },
  },
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns
    local opts = { buffer = bufnr }
    map("n", "]h", gs.next_hunk, opts)   -- next change
    map("n", "[h", gs.prev_hunk, opts)   -- prev change
    map("n", "<leader>hs", gs.stage_hunk, opts)
    map("n", "<leader>hr", gs.reset_hunk, opts)
    map("n", "<leader>hp", gs.preview_hunk, opts)
    map("n", "<leader>hb", gs.blame_line, opts)
  end,
})

-- ============================================================
-- Git panel (neogit — equivalent of VSCode git tab)
-- ============================================================
require("neogit").setup({})

map("n", "<leader>g", ":Neogit<CR>")

-- nixd: tell it where your flake is
lspconfig.nixd.setup({
  on_attach = on_attach,
  settings = {
    nixd = {
      nixpkgs = {
        expr = "import <nixpkgs> {}",
      },
      formatting = {
        command = { "nixfmt" },
      },
    },
  },
})