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
          env = {
            api_key = "cmd:op read op://Private/OctoAIKey/credential",
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
        adapter = "anthropic",
      },
      agent = {
        adapter = "openai",
      },
    },
    default_prompts = {
      ["Explain Code"] = {
        strategy = "chat",
        description = "Explain the selected code",
        opts = {
          modes = { "v" },
          mapping = "<LocalLeader>ce",
        },
      },
      ["Generate Tests"] = {
        strategy = "chat",
        description = "Generate unit tests for the selected code",
        opts = {
          modes = { "v" },
          mapping = "<LocalLeader>ct",
        },
      },
    },
  },
}
