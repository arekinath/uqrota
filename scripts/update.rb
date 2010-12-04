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

mode = :timetables
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
    mode = :timetables
  elsif arg == 'profiles'
    mode = :profiles
  elsif arg == 'semesters'
    mode = :semesters
  end
end

if mode == :timetables
  offerings = Offering.all(:semester => target_semester)
  tasks = offerings.collect { |o| UpdateTasks::TimetableTask.new(o) }
  
  t = TaskRunner.new(tasks)
  t.run("Timetable update for #{target_semester['id']}/#{target_semester.name}")
end

