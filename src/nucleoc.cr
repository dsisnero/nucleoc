# Main entry point for the nucleoc library
require "./nucleoc/config"
require "./nucleoc/chars"
require "./nucleoc/utf32_str"
require "./nucleoc/score"
require "./nucleoc/matcher"
require "./nucleoc/pattern"
require "./nucleoc/prefilter"
require "./nucleoc/api"

# TODO: Write documentation for `Nucleoc`
module Nucleoc
  VERSION = "0.1.0"
end
