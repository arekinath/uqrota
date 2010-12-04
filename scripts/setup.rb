#!/usr/bin/ruby

require File.expand_path("../../lib/config", __FILE__)
require 'rota/model'
require 'rota/fetcher'
require 'rota/updater'
require 'rota/queues_alerts'

require 'dm-migrations'

mode = :fresh
while (arg = ARGV.shift)
  if arg == '--upgrade'
    mode = :upgrade
  end
end

puts "Creating database tables..."
if mode == :fresh
  DataMapper.auto_migrate!
elsif mode == :upgrade
  DataMapper.auto_upgrade!
end

puts "Fetching semester list..."
Rota::UpdateTasks::SemesterListTask.new.run

puts "Rota DB setup complete.\n"

puts "You probably want to run 'scripts/update.rb buildings programs profiles' to fetch"
puts "an initial dataset."