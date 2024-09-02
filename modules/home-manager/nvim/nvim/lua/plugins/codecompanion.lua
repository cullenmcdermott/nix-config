return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-telescope/telescope.nvim",
    {
      "stevearc/dressing.nvim",
      opts = {},
    },
  },
  opts = {
    adapters = {
      chat_adapter = function()
        return require("codecompanion.adapters").extend("openai", {
          url = "https://text.octoai.run/v1",
          model = "meta-llama-3.1-8b-instruct",
          env = {
            api_key = "cmd:op read op://Private/OctoAIKey/credential",
          },
          parameters = {
            model = "meta-llama-3.1-8b-instruct",
          },
        })
      end,
      inline_adapter = function()
        return require("codecompanion.adapters").extend("anthropic", {
          env = {
            api_key = "cmd:op read op://Private/AnthropicAPIKey/credential",
          },
        })
      end,
    },
    ui = {
      border = "rounded",
      width = 0.6,
      height = 0.8,
    },
    logger = {
      level = vim.log.levels.TRACE,
      path = vim.fn.stdpath("cache") .. "/codecompanion.log",
    },
    strategies = {
      chat = {
        adapter = "chat_adapter",
        auto_submit = false,
        auto_expand = true,
      },
      inline = {
        adapter = "inline_adapter",
        trigger_characters = { ".", ":", "(", "'" },
      },
      agent = {
        adapter = "chat_adapter",
        context_window = 10,
      },
    },
    commands = {
      ask = { strategies = { "chat" } },
      edit = { strategies = { "chat" } },
      complete = { strategies = { "inline" } },
    },
  },
}
