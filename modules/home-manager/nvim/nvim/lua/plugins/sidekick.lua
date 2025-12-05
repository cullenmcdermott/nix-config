return {
  "folke/sidekick.nvim",
  config = function()
    -- Enable Copilot LSP
    vim.lsp.enable "copilot"

    -- Setup sidekick
    require("sidekick").setup {
      cli = {
        tools = {
          claude = {
            cmd = { "claude", "--mcp-config", os.getenv "HOME" .. "/.claude/mcp.json" },
          },
        },
      },
    }
  end,
  keys = {
    { "<leader>a", nil, desc = "AI/Claude" },
    {
      "<leader>ac",
      function() require("sidekick.cli").toggle { name = "claude", focus = true } end,
      desc = "Toggle Claude",
    },
    { "<leader>af", function() require("sidekick.cli").focus { name = "claude" } end, desc = "Focus Claude" },
    { "<leader>at", "<cmd>Sidekick send<cr>", mode = "v", desc = "Send selection to Claude" },
    { "<leader>aF", "<cmd>Sidekick send file<cr>", desc = "Send file to Claude" },
    { "<leader>ap", function() require("sidekick.cli").prompt() end, desc = "Choose prompt" },
    -- Edit management
    { "<leader>aa", "<cmd>Sidekick nes apply<cr>", desc = "Accept edit" },
    { "<leader>ad", "<cmd>Sidekick nes clear<cr>", desc = "Decline edit" },
    { "<leader>aj", "<cmd>Sidekick nes jump<cr>", desc = "Jump to edit" },
  },
}
