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

$stderr.reopen(File.new("/var/log/uqrota/webserv.log", "a"))
$stdout.reopen(File.new("/var/log/uqrota/webserv.log", "a"))
$stderr.sync = true
$stdout.sync = true

Rota.setup_and_finalize

if __FILE__ == $0
  RotaApp.run!
end
