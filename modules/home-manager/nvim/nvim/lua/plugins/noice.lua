-- lazy.nvim
return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {},
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  config = function()
    require("notify").setup {
      top_down = false,
    }

    require("noice").setup {}
  end,
}
