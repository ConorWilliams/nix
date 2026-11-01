-- Treesitter: syntax highlighting, folds and indentation from a real parse
-- tree. The plugin and parsers come from Nix (home/server/neovim.nix); add a
-- language there. The nvim-treesitter main branch turns nothing on by
-- itself, so do it here whenever a buffer's filetype has a parser.

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('config-treesitter', {}),
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if not (lang and vim.treesitter.language.add(lang)) then return end

    vim.treesitter.start(ev.buf, lang)
    if vim.treesitter.query.get(lang, 'folds') then
      vim.wo.foldmethod = 'expr'
      vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    end
    if vim.treesitter.query.get(lang, 'indents') then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
