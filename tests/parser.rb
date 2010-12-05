require File.expand_path("../../lib/config", __FILE__)

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rota/fetcher'
require 'rota/queues_alerts'
require 'rubygems'

require 'dm-migrations'
DataMapper.auto_migrate!
require 'nokogiri'

require 'bacon'
require 'fixtures'

include Rota

class FakePage
  attr_reader :parser

  def initialize(fname)
    fname = File.expand_path("../#{fname}", __FILE__)
    @parser = Nokogiri::HTML(File.new(fname))
  end 
end

describe 'CoursePageParser (MATH2000/sumsem10)' do
  before do
    agent, page = Semester.fetch_list
    Semester.parse_list(page)
  
    @page = FakePage.new('fixtures/math2000_sumsem10_tt.html')
    @page_mod = FakePage.new('fixtures/math2000_sumsem10_tt_modified.html')
    @course = Course.new
    @course.code = "MATH2000"
    @course.save
    
    @offering = Offering.new
    @offering.course = @course
    @offering.semester = Semester.current
    @offering.save
    
    @offering.parse_timetable(@page)
    
    @fix = FixtureSet.new("tests/fixtures/parser.yml")
    @fix.save
  end
  
  after do
    @offering.destroy!
    @course.destroy!
    @fix.destroy!
    QueuedEmail.each { |e| e.destroy! }
    QueuedSMS.each { |s| s.destroy! }
  end
  
  it 'should create series objects' do
    ss = @offering.series.collect { |s| s.name }
    ss.size.should.equal 2
    ss.should.include? 'L'
    ss.should.include? 'T'
  end
  
  it 'should create group objects' do
    lser = @offering.series.first(:name => 'L')
    tser = @offering.series.first(:name => 'T')
    lser.groups.size.should.equal 1
    tser.groups.size.should.equal 12
  end
  
  it 'should create session objects' do
    lser = @offering.series.first(:name => 'L')
    
    lg = lser.groups.first
    lg.reload
    lg.should.not.nil?
    lg.sessions.size.should.equal 4
    
    ltue = lg.sessions.first(:day => 'Tue')
    ltue.should.not.nil?
    ltue.start.should.equal 10*60
    
    tser = @offering.series.first(:name => 'T')
    t8 = tser.groups.first(:name => '8')
    t8.reload
    t8wed = t8.sessions(:day => 'Wed').first
    t8wed.should.not.nil?
    t8wed.start.should.equal 11*60
  end
  
  it 'should update information accurately' do
    @offering.parse_timetable(@page_mod)
    
    lser = @offering.series.first(:name => 'L')
    lg = lser.groups.first
    lg.reload
    lfri = lg.sessions.first(:day => 'Fri')
    lfri.should.not.nil?
    lfri.reload
    lfri.start.should.equal 10*60
    
    tser = @offering.series.first(:name => 'T')
    t1 = tser.groups.first(:name => '1')
    t1.reload
    t1wed = t1.sessions.first(:day => 'Wed')
    t1wed.should.not.nil?
    t1wed.reload
    t1wed.start.should.equal 11*60 + 30
    t1wed.finish.should.equal 12*60 + 20
  end
  
  it 'should provide email alerts when changes occur' do
    lser = @offering.series.first(:name => 'L')
    lg = lser.groups.first
    @fix.tt_email.groups << lg
    @fix.tt_email.save
    lg.reload
    
    @offering.parse_timetable(@page_mod)
    
    ems = QueuedEmail.all
    ems.size.should.equal 1
    ems.first.recipient.should.equal @fix.user.email
    ems.first.subject.should.include? 'MATH2000 L'
    
    QueuedSMS.all.size.should.equal 0
  end
  
  it 'should provide SMS alerts when changes occur' do
    tser = @offering.series.first(:name => 'T')
    t1 = tser.groups.first(:name => '1')
    @fix.tt_sms.groups << t1
    @fix.tt_sms.save
    t1.reload
    
    @offering.parse_timetable(@page_mod)
    
    sms = QueuedSMS.all
    sms.size.should.equal 1
    sms.first.text.should.include? 'MATH2000 T1'
    QueuedEmail.all.size.should.equal 1
  end
end

describe 'CoursePageParser (nurs2003/sumsem10) [incomplete]' do
  before do
    agent, page = Semester.fetch_list
    Semester.parse_list(page)
    
    @page = FakePage.new('fixtures/nurs3002_sumsem10.html')
    @course = Course.new
    @course.code = "NURS3002"
    @course.save
    
    @offering = Offering.new
    @offering.course = @course
    @offering.semester = Semester.current
    @offering.save
    
    @offering.parse_timetable(@page)
  end
  
  after do
    @offering.destroy!
    @course.destroy!
  end
  
  it 'should create series objects' do
    @offering.reload
    @offering.series.size.should.equal 1
    @offering.series.first.name.should.equal 'W'
  end
end