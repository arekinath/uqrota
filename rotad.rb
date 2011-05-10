#!/usr/bin/ruby

require File.expand_path('../lib/config', __FILE__)
require 'app'

if __FILE__ == $0
  RotaApp.run!
end