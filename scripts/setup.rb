#!/usr/bin/ruby

require File.expand_path("../../lib/config", __FILE__)
require 'rota/model'
require 'rota/fetcher'
require 'rota/updater'
require 'rota/queues_alerts'

require 'dm-migrations'

puts "Creating database tables..."
DataMapper.auto_migrate!

puts "Fetching semester list..."
Rota::UpdateTasks::SemesterListTask.new.run

puts "Rota DB setup complete.\n"

puts "You probably want to run 'scripts/update.rb buildings programs profiles' to fetch"
puts "an initial dataset."