-- ty: Python types, go-to-definition, hover. Finds the project's .venv
-- for imports by itself.
return {
  cmd = require('config.venv')('ty', { 'server' }),
  -- A uv workspace's top (uv.lock, where its .venv is) before the nearest
  -- pyproject.toml, which in a workspace is a member's: from there ty
  -- doesn't see the .venv. Then nvim-lspconfig's own markers.
  root_markers = {
    'uv.lock',
    'ty.toml',
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    '.git',
  },
}
