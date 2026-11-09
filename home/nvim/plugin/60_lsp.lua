-- Language servers. The servers themselves come from Nix (extraPackages in
-- home/nvim.nix), or for project toolchains (rust-analyzer, ruff, ty) from
-- the project's direnv/devshell, on the PATH nvim starts with. nvim-lspconfig only supplies default configs (command,
-- filetypes, root markers) as lsp/<name>.lua files; per-server tweaks
-- live in after/lsp/<name>.lua and are merged on top.

local servers = {
  'lua_ls', -- lua-language-server
  'nixd',
  'bashls', -- bash-language-server (sh and bash)
  'ty', -- Python types
  'ruff', -- Python lint and format
  'rust_analyzer', -- Rust (formats with rustfmt)
  'marksman', -- Markdown links, headings, references
  'rumdl', -- Markdown lint and format
  'copilot', -- inline suggestions (80_ai.lua)
}
vim.lsp.enable(servers)

-- Rather than silently no LSP, warn (once per server) when a file's server
-- isn't installed, e.g. missing from the project's devshell.
local warned = {}
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('config-lsp-missing', {}),
  callback = function(ev)
    for _, name in ipairs(servers) do
      local config = vim.lsp.config[name]
      local exe = config and type(config.cmd) == 'table' and config.cmd[1]
      if
        exe
        and not warned[name]
        and vim.tbl_contains(config.filetypes or {}, ev.match)
        and vim.fn.executable(exe) == 0
      then
        warned[name] = true
        vim.notify(('%s: `%s` not found'):format(name, exe), vim.log.levels.WARN)
      end
    end
  end,
})

-- Keys for buffers with a server attached, as in LazyVim. Built in already:
-- K hover, [d ]d diagnostics, gO document symbols.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('config-lsp', {}),
  callback = function(ev)
    -- Not for copilot, which only does inline suggestions (80_ai.lua)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name == 'copilot' then return end
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    -- Through the picker (55_picker.lua): jumps straight there if there's
    -- only one result, else lists them with a preview.
    map('n', 'gd', Snacks.picker.lsp_definitions, 'Goto definition')
    map('n', 'gD', Snacks.picker.lsp_declarations, 'Goto declaration')
    -- nowait: at once, not waiting to see if it's one of the built-in gr* keys
    vim.keymap.set('n', 'gr', Snacks.picker.lsp_references, {
      buffer = ev.buf,
      desc = 'References',
      nowait = true,
    })
    map('n', 'gI', Snacks.picker.lsp_implementations, 'Goto implementation')
    map('n', 'gy', Snacks.picker.lsp_type_definitions, 'Goto type definition')
    map({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, 'Code action')
    map('n', '<leader>cr', vim.lsp.buf.rename, 'Rename')
  end,
})

-- Inline type hints (e.g. ty's inferred types): on; <leader>uh toggles.
vim.lsp.inlay_hint.enable()
-- (all buffers: snacks' own inlay_hints toggle is per buffer)
Snacks.toggle({
  name = 'Inlay hints',
  get = function() return vim.lsp.inlay_hint.is_enabled() end,
  set = function(on) vim.lsp.inlay_hint.enable(on) end,
}):map('<leader>uh')

-- Language servers' progress (indexing, loading the workspace...) as
-- progress messages, which ui2 shows in its message window (from :h
-- LspProgress).
vim.api.nvim_create_autocmd('LspProgress', {
  group = vim.api.nvim_create_augroup('config-lsp-progress', {}),
  callback = function(ev)
    local value = ev.data.params.value
    vim.api.nvim_echo({ { value.message or 'done' } }, false, {
      id = 'lsp.' .. ev.data.params.token,
      kind = 'progress',
      source = 'vim.lsp',
      title = value.title,
      status = value.kind ~= 'end' and 'running' or 'success',
      percent = value.percentage,
    })
  end,
})

-- How diagnostics are shown
vim.diagnostic.config({
  severity_sort = true, -- Errors above warnings when several share a line
  virtual_text = { spacing = 4, source = 'if_many', prefix = '●' },
  float = { source = 'if_many' },
  -- Gutter icons (nerd font), as codepoints so they survive any editor
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = vim.fn.nr2char(0xf057),
      [vim.diagnostic.severity.WARN] = vim.fn.nr2char(0xf071),
      [vim.diagnostic.severity.HINT] = vim.fn.nr2char(0xf0eb),
      [vim.diagnostic.severity.INFO] = vim.fn.nr2char(0xf05a),
    },
  },
  -- Every jump ([d ]d, ]e [e ...) shows the diagnostic in a float
  jump = {
    on_jump = function(diagnostic, bufnr)
      if diagnostic then
        vim.diagnostic.open_float({ bufnr = bufnr, scope = 'cursor', focus = false })
      end
    end,
  },
})
