
require File.expand_path("../../lib/config", __FILE__)

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rubygems'

require 'dm-migrations'
DataMapper.auto_migrate!

require 'bacon'

include Rota::Model

describe 'An API session' do
  it 'should generate different ids' do
    id1 = APISession.gen_id
    id2 = APISession.gen_id
    
    id1.should.not.equal id2
  end
  
  it 'should create new sessions' do
    s = APISession.create
    s.nil?.should.equal false
  end
  
  it 'should set attributes on new sessions' do
    s = APISession.create
    s['id'].size.should.equal APISession.gen_id.size
    s.expires.is_a?(Integer).should.equal true
    s.expires.should.be > 0
  end
  
  it 'should support methods for determining expiry' do
    s = APISession.create
    s.expires_dt.is_a?(DateTime).should.equal true
    s.expires_dt.should.be > DateTime.now
    s.expired?.should.equal false
  end
end

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
    @s1 = Session.new
    @s1.day = 'Mon'
    @s1.start = 8*60
    @s1.finish = 9*60
    @s1.dates = "01/01/2001 - 01/02/2001"
    @s1.exceptions = "08/01/2001; 22/01/2001"
    @s1.save
    
    @s2 = Session.new
    @s2.day = 'Tue'
    @s2.start = 9*60
    @s2.finish = 10*60
    @s2.dates = "04/01/2005 - 04/02/2005"
    @s2.exceptions = " "
    @s2.save
    
    @s3 = Session.new
    @s3.day = ' '
    @s3.dates = " "
    @s3.exceptions = " "
    @s3.save
    
    @s1.build_events
    @s2.build_events
    @s3.build_events
  end

  it 'should build the correct number of events with everything specified' do
    @s1.events.size.should.equal 5
  end
  
  it 'should build the correct number with whitespace in exceptions' do
    @s2.events.size.should.equal 5
  end
  
  it 'should build the correct number with whitespace in all fields' do
    @s3.events.size.should.equal 0
  end
  
  it 'should exclude exceptions' do
    @s1.events.select { |ev| ev.taught }.size.should.equal 3
    @s2.events.select { |ev| ev.taught }.size.should.equal 5
    
    weeks = @s1.events.select { |ev| not ev.taught }.collect { |ev| ev.week_number }
    weeks.should.equal [ 2, 4 ]
  end
  
  it 'should convert times to mins-from-midnight correctly' do
    Session.mins_from_string('5:00 AM').should.equal 5*60
    Session.mins_from_string('05:00 PM').should.equal 17*60
    Session.mins_from_string('6:31 AM').should.equal 6*60+31
  end
end


