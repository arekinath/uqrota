$LOAD_PATH << File.expand_path("../../lib", __FILE__)
require 'config'
require 'rota/model'
require 'rota/fetcher'

cs = Rota::Model::Course.all(:code => ARGV[0])
course = cs[-1]
puts "selecting from semester: #{course.semester['id']}/#{course.semester.name}"

puts "fetching..."
fetcher = Rota::Fetcher.new
agent,page = fetcher.get_course_page(course)
puts "parsing..."
parser = Rota::CoursePageParser.new(course, page)
parser.parse

puts "done."
