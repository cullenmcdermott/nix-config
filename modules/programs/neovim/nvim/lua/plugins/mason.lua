return {
  {
    "williamboman/mason.nvim",
    ensure_installed = {
      "bashls",
      "gopls",
      "sumneko_lua",
      "terraform-ls",
    },
    -- auto-install configured servers (with lspconfig)
    automatic_installation = true, -- not the same as ensure_installed
    keys = {
      { "<leader>cm", false },
      { "<leader>um", "<cmd>Mason<cr>", desc = "Mason" },
    },
  },
}
