---@type LazySpec
return {
  "echasnovski/mini.misc",
  version = false,
  config = function()
    require("mini.misc").setup()
  end,
  keys = {
    {
      "<leader>z",
      function()
        require("mini.misc").zoom()
      end,
      desc = "Zoom current buffer",
    },
  },
}