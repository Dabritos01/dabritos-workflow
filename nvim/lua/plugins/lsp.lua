return {
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
    },
    opts = {
      ensure_installed = { "ts_ls", "eslint", "graphql" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      -- Keymaps on LSP attach
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
          vim.keymap.set("n", "gl", vim.diagnostic.open_float, { buffer = ev.buf, desc = "Show Line Diagnostics" })
        end,
      })

      -- Use nvim 0.11+ native vim.lsp.config
      vim.lsp.config("ts_ls", {})
      vim.lsp.enable("ts_ls")

      vim.lsp.config("eslint", {})
      vim.lsp.enable("eslint")

      vim.filetype.add({ extension = { gql = "graphql" } })
      vim.lsp.config("graphql", {
        filetypes = { "graphql" },
        root_dir = function(bufnr, on_dir)
          on_dir(vim.fs.root(bufnr, { "schema.gql" }))
        end,
        cmd = function(dispatchers, config)
          local root_dir = assert(config.root_dir)
          local config_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "graphql-lsp", vim.fn.sha256(root_dir))
          local config_path = vim.fs.joinpath(config_dir, "graphql.config.json")
          local config_json = vim.json.encode({ schema = vim.fs.joinpath(root_dir, "schema.gql") })

          vim.fn.mkdir(config_dir, "p")
          vim.fn.writefile({ config_json }, config_path)

          return vim.lsp.rpc.start(
            { "graphql-lsp", "server", "-m", "stream", "-c", config_dir },
            dispatchers,
            { cwd = root_dir }
          )
        end,
      })
      vim.lsp.enable("graphql")

      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
        callback = function(ev)
          local clients = vim.lsp.get_clients({ bufnr = ev.buf, name = "eslint" })
          if #clients > 0 then
            local client = clients[1]
            local params = {
              command = "eslint.applyAllFixes",
              arguments = {
                {
                  uri = vim.uri_from_bufnr(ev.buf),
                  version = vim.lsp.util.buf_versions[ev.buf],
                },
              },
            }
            client:request_sync("workspace/executeCommand", params, 3000, ev.buf)
          end
        end,
      })
    end,
  },
}
