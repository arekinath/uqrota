
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

describe 'A session object' do
  before do
    @fix = FixtureSet.new('tests/fixtures/model.yml')
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


