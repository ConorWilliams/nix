-- ty: Python types, go-to-definition, hover. Finds the project's .venv
-- for imports by itself.
return {
  cmd = require('config.venv')('ty', { 'server' }),
}
