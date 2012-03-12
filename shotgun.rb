$:.unshift(*Dir[File.expand_path("vendor/*/lib", File.dirname(__FILE__))])

require "cuba"
require "mote"
require "octokit"
require "omniauth-github"
require "ohm"
require "json"
require "github/markup"
