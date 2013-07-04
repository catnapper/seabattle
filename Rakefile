task :default => :play

task :play do
  $: << '.'
  require 'lib/seabattle'
  play_seabattle
end

task :test do
  $: << '.'
  require 'lib/seabattle'
  require 'minitest/autorun'
  require 'minitest/spec'
  require 'test/all_tests.rb'
end
