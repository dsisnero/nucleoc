# Main entry point for the nucleoc library
require "log"
require "./nucleoc/config"
require "./nucleoc/chars"
require "./nucleoc/utf32_str"
require "./nucleoc/score"
require "./nucleoc/matcher"
require "./nucleoc/pattern"
require "./nucleoc/prefilter"
require "./nucleoc/boxcar_native"
require "./nucleoc/worker_pool_native"
require "./nucleoc/worker_pool_fiber"
require "./nucleoc/par_sort_native"
require "./nucleoc/multi_pattern_native"
require "./nucleoc/api"

Log.setup_from_env

# TODO: Write documentation for `Nucleoc`
module Nucleoc
  VERSION = "0.1.0"
end
