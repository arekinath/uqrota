require './lib/config'

Rota::Config['database']['uri'] = 'yaml:tests/fixtures/apitests'

require 'rota/model'
require 'rota/fetcher'
require 'rota/queues_alerts'
require 'rota/updater'
require 'dm-migrations'

def log(msg)
  puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] #{msg}"
end

include Rota
log "Pulling in semester list"
UpdateTasks::SemesterListTask.new.run
t = TaskRunner.new(Semester.all.collect { |s| UpdateTasks::SemesterTask.new(s) })
t.run("Update semester details")
log "Fetching building list"
UpdateTasks::BuildingListTask.new.run
log "Fetching program list"
UpdateTasks::ProgramListTask.new.run
log "Fetching first program"
UpdateTasks::ProgramTask.new(Program.first).run
log "Fetching first course"
UpdateTasks::CourseTask.new(Course.first).run
log "Fetching first profile"
UpdateTasks::ProfileTask.new(Offering.first).run
log "Fetching first timetable"
UpdateTasks::TimetableTask.new(Offering.first).run
