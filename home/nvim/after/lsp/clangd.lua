-- Use the project's clangd for diagnostics, clang-tidy checks and formatting.
-- Compile flags, lint checks and style stay in the project's compilation
-- database, .clangd, .clang-tidy and .clang-format.
return {
  cmd = { 'clangd', '--clang-tidy' },
}
