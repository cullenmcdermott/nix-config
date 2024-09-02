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
      log_level = "TRACE",
    },
    log_level = "TRACE",
    adapters = {
      anthropic = function()
        return require("codecompanion.adapters").extend("anthropic", {
          env = {
            api_key = "cmd:op read op://Private/AnthropicAPIKey/credential",
          },
        })
      end,
      openai = function()
        return require("codecompanion.adapters").extend("openai", {
          url = "https://text.octoai.run/v1",
          model = "meta-llama-3.1-8b-instruct",
          env = {
            api_key = "cmd:op read op://Private/OctoAIKey/credential",
            model = "meta-llama-3.1-8b-instruct",
          },
          parameters = {
            model = "meta-llama-3.1-8b-instruct",
          },
        })
      end,
    },
    strategies = {
      chat = {
        adapter = "openai",
      },
      inline = {
        adapter = "openai",
      },
      agent = {
        adapter = "openai",
      },
    },
  },
}
