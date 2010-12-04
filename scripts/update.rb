#!/usr/bin/ruby

require File.expand_path("../../lib/config", __FILE__)
require 'rota/model'
require 'rota/fetcher'
require 'rota/updater'

include Rota

def log(msg)
  puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] #{msg}"
end

log "Updating semester list..."
UpdateTasks::SemesterListTask.new.run

mode = []
target_semester = Semester.current

while (arg = ARGV.shift)
  if arg == '--semester' or arg == '-s'
    semid = ARGV.shift
    if semid == 'list' or semid == 'help'
      Semester.all.each do |sem|
        puts "#{sem['id']} / #{sem.name}"
      end
      Kernel.exit()
    end
    semid = semid.to_i
    target_semester = Semester.get(semid)
  elsif arg == 'timetables'
    mode << :timetables
  elsif arg == 'profiles'
    mode << :profiles
  elsif arg == 'programs'
    mode << :programs
  elsif arg == 'buildings'
    mode << :buildings
  end
end

if mode.size == 0
  log "Nothing to do..."
end

if mode.include? :buildings
  log "Updating building index..."
  UpdateTasks::BuildingListTask.new.run
end

if mode.include? :timetables
  offerings = Offering.all(:semester => target_semester)
  tasks = offerings.collect { |o| UpdateTasks::TimetableTask.new(o) }
  
  t = TaskRunner.new(tasks)
  t.run("Timetable update for #{target_semester['id']}/#{target_semester.name}")
end

if mode.include? :programs
  log "Updating undergraduate program list..."
  UpdateTasks::ProgramListTask.new.run
  
  programs = Program.all
  tasks = programs.collect { |p| UpdateTasks::ProgramTask.new(p) }
  t = TaskRunner.new(tasks)
  t.run("All Programs update")
end

if mode.include? :profiles
  courses = Course.all
  tasks = courses.collect { |c| UpdateTasks::CourseTask.new(c) }
  t = TaskRunner.new(tasks)
  t.run("All Course information update")
  
  tasks = []
  Course.all.each do |c|
    pp = c.offerings.select { |o| o.current and o.profileId > 0 }.first
    if pp.nil?
      pp = c.offerings.select { |o| o.profileId > 0 }.first
    end
    ps << UpdateTasks::ProfileTask.new(pp) unless pp.nil?
  end
  t = TaskRunner.new(tasks, Rota::Config['updater']['threads']['profiles'])
  t.run("Current course profiles update")
end
