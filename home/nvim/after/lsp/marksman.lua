-- marksman: links and headings in ordinary Markdown. Not inside zk
-- notebooks (a .zk folder above): zk's own server handles [[links]] there
-- by note ID, and marksman's title-based ones would duplicate gd results
-- and completions.
return {
  root_dir = function(bufnr, on_dir)
    local file = vim.api.nvim_buf_get_name(bufnr)
    if vim.fs.root(file, '.zk') then return end -- don't start here
    on_dir(vim.fs.root(file, { '.marksman.toml', '.git' }) or vim.fs.dirname(file))
  end,
}
