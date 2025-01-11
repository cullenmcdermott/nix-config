return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-telescope/telescope.nvim", -- Optional
    {
      "stevearc/dressing.nvim", -- Optional: Improves the default Neovim UI
      opts = {},
    },
  },
  opts = {
    opts = {
      log_level = "DEBUG",
    },
    adapters = {
      anthropic = function()
        return require("codecompanion.adapters").extend("anthropic", {
          env = {
            api_key = "cmd:op read op://Private/AnthropicAPIKey/credential --account erinandcullen.1password.com",
          },
        })
      end,
    },
    strategies = {
      default = {
        adapter = "anthropic",
      },
      chat = {
        adapter = "anthropic",
      },
      inline = {
        adapter = "anthropic",
      },
      agent = {
        adapter = "anthropic",
      },
    },
  },
}
