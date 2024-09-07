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
            api_key = "cmd:op read op://Private/AnthropicAPIKey/credential --account erinandcullen.1password.com",
          },
        })
      end,
      octoai = function()
        return require("codecompanion.adapters").extend("openai", {
          name = "octoai",
          url = "https://text.octoai.run/v1/chat/completions",
          env = {
            api_key = "cmd:op read op://Private/OctoAIKey/credential --account erinandcullen.1password.com",
          },
          schema = {
            model = {
              default = "meta-llama-3.1-70b-instruct",
            },
          },
        })
      end,
    },
    strategies = {
      default = {
        adapter = "copilot",
      },
      chat = {
        adapter = "copilot",
      },
      inline = {
        adapter = "copilot",
      },
      agent = {
        adapter = "copilot",
      },
    },
  },
}
