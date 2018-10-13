require_relative 'DSL'
require_relative 'Options'

# for some reason, lower case variables are not accessible until the next invocation of eval
# so we bind them here, before eval'ing the file
DSL::types [
  :bool,
  :int,
  :unsigned,
  :uintptr_t,
]

options = Options::parse(ARGV)
DSL::run(options)
