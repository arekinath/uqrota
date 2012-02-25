#!/usr/bin/ruby

require File.expand_path('../lib/config', __FILE__)
require 'app'
require 'rota/model'

class RotaApp 
  configure do
    set :environment, :production
    set :port, ARGV[0] ? ARGV[0].to_i : 4567
    set :server, %w[passenger thin mongrel webrick]
    set :bind, '127.0.0.1' 
  end
end

if __FILE__ == $0
  Rota.setup_and_finalize
  RotaApp.run!
end
