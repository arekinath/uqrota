#!/usr/bin/ruby

$LOAD_PATH << File.expand_path("../../lib", __FILE__)
require 'config'
require 'rota/model'
require 'rota/fetcher'
require 'thread'

class ProgramTask
  def initialize(program)
    @program = program
    @f = Rota::Fetcher.new
  end
  
  def run
    begin
      agent,page = @f.get_pgm_course_list_page(@program)
      p = Rota::CourseListPageParser.new(@program, page)
      p.parse
    rescue Timeout::Error => err
      puts "> timeout, retrying..."
      sleep(1)
      retry
    rescue Exception => err
      puts "> error #{err.class.inspect} on #{@course.code}... retrying..."
      sleep(2)
      retry
    end
  end
end

class CourseTask
  def initialize(course)
    @course = course
    @f = Rota::Fetcher.new
  end
  
  def run
    begin
      agent,page = @f.get_course_detail_page(@course)
      p = Rota::CourseDetailPageParser.new(@course, page)
      p.parse
    rescue Timeout::Error => err
      puts "> timeout on #{@course.code}, retrying..."
      sleep(1)
      retry
    rescue Exception => err
      puts "> error #{err.class.inspect} on #{@course.code}... retrying..."
      sleep(2)
      retry
    end
  end
end

class ProfileTask
  def initialize(profile)
    @profile = profile
    @f = Rota::Fetcher.new
  end
  
  def run
    begin
      agent,page = @f.get_course_profile(@profile)
      p = Rota::CourseProfileParser.new(@profile, page)
      p.parse
    rescue Timeout::Error => err
      puts "> timeout, retrying..."
      sleep(1)
      retry
    rescue Exception => err
      puts "> error #{err.class.inspect} on #{@course.code}... retrying..."
      sleep(2)
      retry
    end
  end
end

class ParallelRunner
  def initialize(tasks, nth=4)
    @tasks = tasks
    @mutex = Mutex.new
    @nthreads = nth
    @total = tasks.size
    self.run
  end
  
  def run
    mutex, tasks = [@mutex, @tasks]
    ths = []
    @nthreads.times do
      ths << Thread.new do
        count = 1
        while count > 0
          task = nil
          mutex.synchronize { task = tasks.pop }
          if task
            begin
              task.run
            rescue Exception => err
              puts err.inspect
              puts err.backtrace.join("\n")
              exit(1)
            end
          end
          
          mutex.synchronize { count = tasks.size }
        end
      end
    end
    
    print "starting..."
    count = 1
    while count > 0
      sleep(1)
      @mutex.synchronize { count = @tasks.size }
      pc = "%.2f" % ((@total-count).to_f / @total.to_f * 100.0)
      print "\r#{@total-count}/#{@total} tasks taken (#{pc}\%)"
    end
    
    ths.each { |th| th.join }
  end
end

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
pgms = Rota::Model::UqProgram.all
pgms = pgms.collect { |p| ProgramTask.new(p) }
ParallelRunner.new(pgms)
end

puts "\nFetching course pages..."
cs = Rota::Model::UqCourse.all.collect { |c| CourseTask.new(c) }
ParallelRunner.new(cs)

puts "\nFetching course profiles..."
ps = []
Rota::Model::UqCourse.all.each do |c|
  pp = c.uq_course_profiles.select { |p| p.current and p.profileId > 0 }.first
  if pp.nil?
    pp = c.uq_course_profiles.select { |p| p.profileId > 0 }.first
  end
  ps << ProfileTask.new(pp) unless pp.nil?
end
ParallelRunner.new(ps, 8)

puts "\ndone!"
