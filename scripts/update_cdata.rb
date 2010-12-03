#!/usr/bin/ruby

$LOAD_PATH << File.expand_path("../../lib", __FILE__)
require 'config'
require 'rota/model'
require 'rota/fetcher'
require 'rota/updater'

include Rota
include Rota::UpdateTasks

puts "Fetching undergraduate plpp..."
f = Rota::Fetcher.new
agent,page = f.get_pgm_list_page
puts "Parsing..."
p = Rota::ProgramListPageParser.new(page)
p.parse

puts "Fetching building list index..."
agent,page = f.get_building_index
p = Rota::BuildingIndexParser.new(page)
p.parse

unless ARGV.include?("--skip_programs")
puts "\nFetching program lists..."
pgms = Rota::Model::Program.all
pgms = pgms.collect { |pg| ProgramTask.new(pg) }
TaskRunner.new(pgms)
end

puts "\nFetching course pages..."
cs = Rota::Model::Course.all.collect { |c| CourseTask.new(c) }
TaskRunner.new(cs)

puts "\nFetching course profiles..."
ps = []
Rota::Model::Course.all.each do |c|
  pp = c.course_profiles.select { |pg| pg.current and pg.profileId > 0 }.first
  if pp.nil?
    pp = c.course_profiles.select { |pg| pg.profileId > 0 }.first
  end
  ps << ProfileTask.new(pp) unless pp.nil?
end
TaskRunner.new(ps, Rota::Config['updater']['threads']['profiles'])

puts "\ndone!"
