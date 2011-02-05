
require File.expand_path("../../lib/config", __FILE__)

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rubygems'

require 'dm-migrations'
DataMapper.auto_migrate!

require 'bacon'
require 'fixtures'

include Rota

describe 'The Setting class' do
  it 'should allow setting' do
    s = Setting.set('test', 'blah')
    s.is_a?(Setting).should.equal true
  end
  
  it 'should retrieve the set value' do
    Setting.set('test', 'blah')
    Setting.get('test').value.should.equal 'blah'
  end
end

describe 'A user object' do
  it 'should encrypt the stored password' do
    u = User.new
    u.login = 'test'
    u.password = 'blah'
    u.password_sha1.should.not.equal 'blah'
  end
  
  it 'should check the encrypted password correctly' do
    u = User.new
    u.login = 'test'
    u.password = 'blah'
    u.is_password?('blah').should.equal true
  end
end

describe 'A course object' do
  before do
    @fix = FixtureSet.new('tests/fixtures/prereqs.yml')
    @fix.save
  end
  
  after do
    @fix.destroy!
  end
  
  it 'should recognise its prereqs' do
    @fix.course3.reload
    @fix.course3.prereqs.should.include? @fix.course1
    @fix.course3.prereqs.should.include? @fix.course2
    @fix.course3.prereqs.size.should.equal 2
  end
  
  it 'should recognise its dependents' do
    @fix.course3.reload
    @fix.course3.dependents.should.equal [@fix.course4]
  end
end

describe 'A semester object' do
  before do
    @sem = Semester.new
    @sem.name = "Semester 2, 2010"
    @sem.start_week = 13
    @sem.finish_week = 21
    @sem.midsem_week = 17
    
    @sem_b = Semester.new
    @sem_b.name = "Summer Semester, 2012"
    @sem_b.start_week = 50
    @sem_b.finish_week = 10
    @sem_b.midsem_week = 2
  end
  
  it 'should calculate week numbers before the midsem break' do
    @sem.week(2).should.equal [2010, 14]
    @sem.week(3).should.equal [2010, 15]
  end
  
  it 'should calculate week numbers after the midsem break' do
    @sem.week(5).should.equal [2010, 18]
    @sem.week(8).should.equal [2010, 21]
  end
  
  it 'should calculate across a year boundary' do
    @sem_b.week(5).should.equal [2013, 1]
    @sem_b.week(7).should.equal [2013, 4]
  end
  
  it 'should iterate over weeks during one year' do
    weeks = [13,14,15,16,17,18,19,20,21]
    @sem.each_week do |week, mon, fri|
      weeks.first.should.equal week
      mon.strftime('%W').to_i.should.equal week
      fri.strftime('%W').to_i.should.equal week
      mon.wday.should.equal 1
      fri.wday.should.equal 5
      weeks.delete_at(0)
    end
  end
  
  it 'should iterate over weeks across a year boundary' do
    weeks = [50,51,52,53,1,2,3,4,5,6,7,8,9,10]
    @sem_b.each_week do |week, mon, fri|
      weeks.first.should.equal week
      weeks.delete_at(0)
    end
  end
end

describe 'A session object' do
  before do
    @fix = FixtureSet.new('tests/fixtures/sessions.yml')
    @fix.save
    
    @fix.s1.build_events
    @fix.s2.build_events
    @fix.s3.build_events
  end
  
  after do
    @fix.destroy!
  end

  it 'should build the correct number of events with everything specified' do
    @fix.s1.events.size.should.equal 5
  end
  
  it 'should build the correct number with whitespace in exceptions' do
    @fix.s2.events.size.should.equal 5
  end
  
  it 'should build the correct number with whitespace in all fields' do
    @fix.s3.events.size.should.equal 0
  end
  
  it 'should exclude exceptions' do
    @fix.s1.events.select { |ev| ev.taught }.size.should.equal 3
    @fix.s2.events.select { |ev| ev.taught }.size.should.equal 5
    
    weeks = @fix.s1.events.select { |ev| not ev.taught }.collect { |ev| ev.week_number }
    weeks.should.equal [ 2, 4 ]
  end
  
  it 'should convert times to mins-from-midnight correctly' do
    TimetableSession.mins_from_string('5:00 AM').should.equal 5*60
    TimetableSession.mins_from_string('05:00 PM').should.equal 17*60
    TimetableSession.mins_from_string('08:11 AM').should.equal 8*60+11
    TimetableSession.mins_from_string('6:31 AM').should.equal 6*60+31
  end
  
  it 'should handle invalid times' do
    TimetableSession.mins_from_string('5:').should.nil?
    TimetableSession.mins_from_string(' ').should.nil?
  end
end


