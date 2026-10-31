-- A `cmd` for Python language servers: run <tool> from the project's .venv
-- if it has one (so the project's pinned ruff/ty win), else the one on PATH
-- (from Nix). Used by after/lsp/ruff.lua and after/lsp/ty.lua.
return function(tool, args)
  return function(dispatchers, config)
    local exe = tool
    if config.root_dir then
      local venv_exe = vim.fs.joinpath(config.root_dir, '.venv', 'bin', tool)
      if vim.fn.executable(venv_exe) == 1 then exe = venv_exe end
    end
    return vim.lsp.rpc.start({ exe, unpack(args) }, dispatchers, {
      cwd = config.cmd_cwd or config.root_dir,
      env = config.cmd_env,
    })
  end
end
