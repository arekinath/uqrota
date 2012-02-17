#!/usr/bin/ruby

require File.expand_path('../lib/config', __FILE__)
require 'app'

class RotaApp 
  configure do
    set :port, ARGV[0] ? ARGV[0].to_i : 4567 
  end
end

if __FILE__ == $0
  RotaApp.run!
end
