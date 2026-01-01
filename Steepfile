target :lib do
  signature "sig"
  check "lib"
  collection_config "rbs_collection.yaml"

  ignore "lib/stoplight/admin"
  ignore "lib/stoplight/admin.rb"
  ignore "lib/stoplight/rspec"
  ignore "lib/stoplight/rspec.rb"

  ignore "lib/stoplight/wiring/data_store"
  ignore "lib/stoplight/wiring/default.rb"
  ignore "lib/stoplight/wiring/default_factory_builder.rb"
  ignore "lib/stoplight/wiring/light"
  ignore "lib/stoplight/wiring/light_builder.rb"
  ignore "lib/stoplight/wiring/light_factory"
  ignore "lib/stoplight/wiring/light_factory.rb"
  ignore "lib/stoplight/wiring/public_api.rb"
  ignore "lib/stoplight/wiring/system"
  ignore "lib/stoplight/wiring/system.rb"

  ignore "lib/stoplight.rb"

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
