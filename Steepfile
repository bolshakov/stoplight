target :lib do
  signature "sig"
  check "lib"

  # ignore "lib/templates/*.rb"

  # library "pathname"              # Standard libraries
  # library "strong_json"           # Gems

  configure_code_diagnostics(Steep::Diagnostic::Ruby.lenient)
end

target :strict do
  signature "sig"

  check "lib/stoplight/domain"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.all_error)
end
