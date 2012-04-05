require File.expand_path("../../lib/config", __FILE__)

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rubygems'

Rota.setup_and_finalize

require 'dm-sweatshop'
require 'dm-migrations'
require 'bacon'

include Rota

describe 'The Setting class' do
  before do
    DataMapper.auto_migrate!
  end

  it 'should allow setting' do
    s = Setting.set('test', 'blah')
    s.is_a?(Setting).should.equal true
  end
  
  it 'should retrieve the set value' do
    Setting.set('test', 'blah')
    Setting.get('test').value.should.equal 'blah'
  end
end

describe 'JSON serializer' do
  before do
    DataMapper.auto_migrate!
  end
  
  it 'should serialize a Setting object' do
    s = Setting.set('test', 'foo')
    o = JSON.parse(s.to_json)
    o['name'].should.equal 'test'
    o['value'].should.equal 'foo'
    o['_class'].should.equal 'Setting'
    o['_keys'].size.should.equal 1
    o['_keys'][0].should.equal 'name'
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
  
  it 'should correctly tell the week number of a date' do
    @sem.week_of(DateTime.parse("5/4/2010")).should.equal 2
    @sem.week_of(DateTime.parse("1/1/2010")).should.equal :before
    @sem.week_of(DateTime.parse("21/4/2010")).should.equal 4
    @sem.week_of(DateTime.parse("27/4/2010")).should.equal :midsem
    @sem.week_of(DateTime.parse("5/5/2010")).should.equal 5
    @sem.week_of(DateTime.parse("1/9/2010")).should.equal :after
  end
  
  it 'should iterate over weeks during one year' do
    weeks = [13,14,15,16,17,18,19,20,21]
    ns =    [ 1, 2, 3, 4, :midsem, 5, 6, 7, 8]
    @sem.each_week do |n, yweek, mon, fri|
      weeks.first.should.equal yweek
      ns.first.should.equal n
      mon.strftime('%W').to_i.should.equal yweek
      fri.strftime('%W').to_i.should.equal yweek
      mon.wday.should.equal 1
      fri.wday.should.equal 6
      weeks.delete_at(0)
      ns.delete_at(0)
    end
  end
  
  it 'should iterate over weeks across a year boundary' do
    weeks = [50,51,52,53,1,2,3,4,5,6,7,8,9,10]
    ns =    [ 1, 2, 3, 4,5,:midsem,6,7,8,9,10,11,12,13]
    @sem_b.each_week do |n, yweek, mon, fri|
      weeks.first.should.equal yweek
      ns.first.should.equal n
      ns.delete_at(0)
      weeks.delete_at(0)
    end
  end
end

describe 'A session object' do
  before do
    DataMapper.auto_migrate!
    
    course = Course.create(:code => 'BLAH1234')
    sem = Semester.create(:name => 'foo', :start_week => 12, :finish_week => 18, :midsem_week => 14)
    camp = Campus.create(:code => 'FOO')
    off = Offering.create(:semester => sem, :course => course, :campus => camp)
    series = TimetableSeries.create(:name => 'L', :offering => off)
    group = TimetableGroup.create(:name => '1', :timetable_series => series)
    build = Building.create(:number => 42)
    
    @s1 = TimetableSession.create(:timetable_group => group, 
                                  :day => 'Tue', :building => build,
                                  :start => 8*60, :finish => 9*60,
                                  :dates => '1/4/2012 - 13/5/2012',
                                  :exceptions => '24/4/2012; 1/5/2012')
    @s2 = TimetableSession.create(:timetable_group => group,
                                  :day => 'Tue', :building => build,
                                  :start => 8*60, :finish => 9*60,
                                  :dates => '1/4/2012 - 13/5/2012',
                                  :exceptions => ' ')
    @s3 = TimetableSession.create(:timetable_group => group,
                                  :day => ' ', :building => build,
                                  :start => 0, :finish => 0,
                                  :dates => ' ',
                                  :exceptions => ' ')
    
    @s1.build_events
    @s2.build_events
    @s3.build_events
  end

  it 'should build the correct number of events with everything specified' do
    @s1.events.size.should.equal 6
  end
  
  it 'should build the correct number with whitespace in exceptions' do
    @s2.events.size.should.equal 6
  end
  
  it 'should build the correct number with whitespace in all fields' do
    @s3.events.size.should.equal 0
  end
  
  it 'should exclude exceptions' do
    @s1.events.select { |ev| ev.taught }.size.should.equal 4
    @s2.events.select { |ev| ev.taught }.size.should.equal 6
    
    weeks = @s1.events.select { |ev| not ev.taught }.collect { |ev| ev.week_number }
    weeks.should.equal [ 17, 18 ]
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


