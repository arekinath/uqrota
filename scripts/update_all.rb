#!/usr/bin/ruby

$LOAD_PATH << File.expand_path("../../lib", __FILE__)
require 'config'
require 'rota/model'
require 'rota/fetcher'
require 'rota/queues_alerts'
require 'rota/updater'

csem = Rota::Model::Semester.current
while (arg = ARGV.shift)
  if arg == '--semester' or arg == '-s'
    semid = ARGV.shift
    if semid == 'list' or semid == 'help'
      Rota::Model::Semester.all.each do |sem|
        puts "#{sem['id']} / #{sem.name}"
      end
      Kernel.exit()
    end
    semid = semid.to_i
    csem = Rota::Model::Semester.get(semid)
  end
end

f = Rota::Fetcher.new
puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] Starting global update..."
puts "   > Updating semester list..."
f.update_semesters
puts "   > This semester is #{csem['id']}, #{csem.name}"

Rota::Model::ChangelogEntry.make("global updater", "starting global update check for #{csem['id']}/#{csem.name}...")

STDOUT.flush

#courses = Rota::Model::Course.all
#courses = Rota::Model::Course.all(:code => 'MECH4460')
courses = csem.courses
courses.size.times do |i|
  course = courses[i]
  begin
    puts "[%3i/%3i] Updating #{course.code} in semester #{course.semester['id']}..." % [i,courses.size]
    fetcher = Rota::Fetcher.new
    puts "          > Fetching..."
    agent, page = fetcher.get_course_page(course)
    parser = Rota::CoursePageParser.new(course, page)
    puts "          > Parsing..."
    parser.parse
    puts "          > Done."
  rescue Timeout::Error => err
    puts "   !! timeout, retrying... !!"
    retry
  rescue Interrupt => err
    puts "   !! interrupt..."
    raise err
  rescue Exception => err
    puts "   !! exception: #{err.inspect}: #{err.backtrace.join("\n\t\t")}"
  end
  STDOUT.flush
end

puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] Global update complete."
Rota::Model::ChangelogEntry.make("global updater", "global update complete.")
