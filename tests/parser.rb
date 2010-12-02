require File.expand_path("../../lib/config", __FILE__)

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rota/fetcher'
require 'rubygems'

require 'dm-migrations'
DataMapper.auto_migrate!
require 'nokogiri'

require 'bacon'

include Rota::Model

class FakePage
  attr_reader :parser

  def initialize(fname)
    fname = File.expand_path("../#{fname}", __FILE__)
    @parser = Nokogiri::HTML(File.new(fname))
  end 
end

describe 'CoursePageParser' do
  before do
    f = Rota::Fetcher.new
    f.update_semesters
  
    @page = FakePage.new('math2000_sumsem10_tt.html')
    @course = Course.new
    @course.semester = Semester.current
    @course.code = "MATH2000"
    @course.save
    
    @parser = Rota::CoursePageParser.new(@course, @page)
    @parser.parse
  end
  
  it 'should create series objects' do
    ss = @course.series.collect { |s| s.name }
    ss.size.should.equal 2
    ss.should.include? 'L'
    ss.should.include? 'T'
  end
  
  it 'should create group objects' do
    lser = @course.series(:name => 'L').first
    tser = @course.series(:name => 'T').first
    lser.groups.size.should.equal 1
    tser.groups.size.should.equal 12
  end
  
  it 'should create session objects' do
    lser = @course.series(:name => 'L').first
    
    lg = lser.groups.first
    lg.reload
    lg.should.not.nil?
    lg.sessions.size.should.equal 4
    
    ltue = lg.sessions(:day => 'Tue').first
    ltue.should.not.nil?
    ltue.start.should.equal 10*60
    
    tser = @course.series(:name => 'T')
    t8 = tser.groups(:name => '8')
    t8.reload
    t8wed = t8.sessions(:day => 'Wed').first
    t8wed.should.not.nil?
    t8wed.start.should.equal 11*60
  end
end
