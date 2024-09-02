return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  opts = function()
    return {
      debug = true,
      provider = "octoai",
      claude = {
        api_key_name = "cmd:op read op://Private/AnthropicAPIKey/credential",
      },
      vendors = {
        ["octoai"] = {
          endpoint = "https://text.octoai.run/v1",
          model = "meta-llama-3.1-8b-instruct", -- The model name to use with this provider
          api_key_name = "cmd:op read op://Private/OctoAIKey/credential",
        },
      },
      mappings = {
        ask = "<leader>aa",
        edit = "<leader>ae",
        refresh = "<leader>ar",
      },
    }
  end,
  build = ":AvanteBuild",
  keys = function(_, keys)
    local opts =
      require("lazy.core.plugin").values(require("lazy.core.config").spec.plugins["avante.nvim"], "opts", false)
    local mappings = {
      {
        opts.mappings.ask,
        function() require("avante.api").ask() end,
        desc = "avante: ask",
        mode = { "n", "v" },
      },
      {
        opts.mappings.refresh,
        function() require("avante.api").refresh() end,
        desc = "avante: refresh",
        mode = "v",
      },
      {
        opts.mappings.edit,
        function() require("avante.api").edit() end,
        desc = "avante: edit",
        mode = { "n", "v" },
      },
      {
        "<leader>ip",
        function()
          return vim.bo.filetype == "AvanteInput" and require("avante.clipboard").paste_image()
            or require("img-clip").paste_image()
        end,
        desc = "clip: paste image",
      },
    }
    mappings = vim.tbl_filter(function(m) return m[1] and #m[1] > 0 end, mappings)
    return vim.list_extend(mappings, keys)
  end,
  dependencies = {
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
    "zbirenbaum/copilot.lua",
    {
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          use_absolute_path = true,
        },
      },
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}
