target :lib do
  signature "sig"
  check "lib"
  collection_config "rbs_collection.yaml"

  ignore "lib/stoplight/rspec"
  ignore "lib/stoplight/rspec.rb"

  # library "pathname"              # Standard libraries
  # library "strong_json"           # Gems

  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end

# target :strict do
#   signature "sig"
#
#   # check "lib/stoplight/domain"
#   check "lib/stoplight/infrastructure"
#   check "lib/stoplight/wiring"
#   check "lib/stoplight.rb"
#
#   configure_code_diagnostics(Steep::Diagnostic::Ruby.all_error)
# end
