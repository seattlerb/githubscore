# -*- ruby -*-

require "rubygems"
require "hoe"

Hoe.plugin :isolate
Hoe.plugin :seattlerb
Hoe.plugin :rdoc

Hoe.spec "githubscore" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"

  license "MIT"

  dependency "octokit", "~> 4.0"
end

task :run => :isolate do
  proj = ENV["PROJ"] || "zenspider seattlerb"
  ruby "-Ilib bin/githubscore #{proj}"
end

# vim: syntax=ruby
