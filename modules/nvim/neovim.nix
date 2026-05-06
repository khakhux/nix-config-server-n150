# home.nix or a dedicated neovim.nix module

{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      nixd          # Nix LSP
      nixfmt-rfc-style  # formatter nixd will call
      ripgrep    # required for telescope live_grep
      fd         # optional but recommended for faster find_files
    ];

    plugins = with pkgs.vimPlugins; [
      nvim-lspconfig

      # File explorer
      nvim-tree-lua
      #nvim-web-devicons   # icons (needs a nerd font)

      # Fuzzy finder
      telescope-nvim
      plenary-nvim        # telescope dependency

      # Git
      neogit
      gitsigns-nvim

    ];
  };

  home.file.".config/nvim/init.lua".source = ./init.lua;
}