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

describe 'Semester list parser' do
  before do
    @page = FakePage.new('fixtures/semlist.html')
    
    Semester.parse_list(@page)
  end
  
  after do
    Semester.all.each { |s| s.destroy! }
    Setting.each { |s| s.destroy! }
  end
  
  it 'should create semesters with correct IDs' do
    ids = Semester.all.collect { |s| s['id'] }.sort
    ids.should.equal [6020, 6060, 6080, 6120, 6160]
  end
  
  it 'should create semesters with correct names' do
    names = Semester.all.collect { |s| s.name }.sort
    names.should.equal ['Semester 1, 2010', 'Semester 1, 2011',
                        'Semester 2, 2010', 'Semester 2, 2011',
                        'Summer Semester, 2010']
  end
  
  it 'should set the current semester' do
    Semester.current['id'].should.equal 6080
  end
end

describe 'Calendar page parser (against 2010)' do
  before do
    @page = FakePage.new('fixtures/acad_calendar_2010.html')
    @sems = FixtureSet.new("tests/fixtures/dummy_semesters.yml")
    @sems.save
    
    @sems.sem1.parse_dates(@page)
    @sems.sem2.parse_dates(@page)
  end
  
  after do
    @sems.destroy!
  end
  
  it 'should get the weeks for sem 1 correct' do
    @sems.sem1.start_week.should.equal 9
    @sems.sem1.midsem_week.should.equal 14
    @sems.sem1.finish_week.should.equal 22
  end
  
  it 'should get the weeks for sem 2 correct' do
    @sems.sem2.start_week.should.equal 30
    @sems.sem2.midsem_week.should.equal 39
    @sems.sem2.finish_week.should.equal 43
  end
end

describe 'Course page parser (MATH2000/sumsem10)' do
  before do
    @sems = FixtureSet.new("tests/fixtures/dummy_semesters.yml")
    @sems.save
  
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
    
    @offering.reload
    
    @fix = FixtureSet.new("tests/fixtures/parser.yml")
    @fix.save
  end
  
  after do
    @offering.destroy!
    @course.destroy!
    @fix.destroy!
    @sems.destroy!
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
    lg.should.not.nil?
    lg.sessions.size.should.equal 4
    
    ltue = lg.sessions.first(:day => 'Tue')
    ltue.should.not.nil?
    ltue.start.should.equal 10*60
    
    tser = @offering.series.first(:name => 'T')
    t8 = tser.groups.first(:name => '8')
    t8wed = t8.sessions(:day => 'Wed').first
    t8wed.should.not.nil?
    t8wed.start.should.equal 11*60
  end
  
  it 'should update information accurately' do
    @offering.parse_timetable(@page_mod)
    @offering.reload
    
    lser = @offering.series.first(:name => 'L')
    lg = lser.groups.first
    lfri = lg.sessions.first(:day => 'Fri')
    lfri.should.not.nil?
    lfri.start.should.equal 10*60
    
    tser = @offering.series.first(:name => 'T')
    t1 = tser.groups.first(:name => '1')
    t1wed = t1.sessions.first(:day => 'Wed')
    t1wed.should.not.nil?
    t1wed.start.should.equal 11*60 + 30
    t1wed.finish.should.equal 12*60 + 20
  end
  
  it 'should provide email alerts when changes occur' do
    lser = @offering.series.first(:name => 'L')
    lg = lser.groups.first
    @fix.tt_email.groups << lg
    @fix.tt_email.save
    
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
    
    @offering.parse_timetable(@page_mod)
    
    sms = QueuedSMS.all
    sms.size.should.equal 1
    sms.first.text.should.include? 'MATH2000 T1'
    QueuedEmail.all.size.should.equal 1
  end
end

describe 'Course page parser (nurs2003/sumsem10) [incomplete]' do
  before do
    @sems = FixtureSet.new("tests/fixtures/dummy_semesters.yml")
    @sems.save
    
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
    @sems.destroy!
  end
  
  it 'should create series objects' do
    @offering.series.size.should.equal 1
    @offering.series.first.name.should.equal 'W'
  end
end