# Main entry point for the nucleoc library
require "log"
require "./nucleoc/config"
require "./nucleoc/chars"
require "./nucleoc/utf32_str"
require "./nucleoc/score"
require "./nucleoc/matcher"
require "./nucleoc/pattern"
require "./nucleoc/prefilter"
require "./nucleoc/boxcar"
require "./nucleoc/worker_pool"
require "./nucleoc/worker_pool_cml"
require "./nucleoc/api"
require "./nucleoc/error_handling"

Log.setup_from_env

# TODO: Write documentation for `Nucleoc`
module Nucleoc
  VERSION = "0.1.0"
end
