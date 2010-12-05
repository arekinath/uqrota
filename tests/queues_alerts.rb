require File.expand_path("../../lib/config", __FILE__)

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rota/queues_alerts'
require 'rubygems'

require 'dm-migrations'
DataMapper.auto_migrate!
require 'nokogiri'

require 'bacon'
require 'fixtures'

include Rota

shared "a fixture test" do
  before do
    @fix = FixtureSet.new("tests/fixtures/alerts.yml")
    @fix.tt.groups << @fix.group
    @fix.tt2.groups << @fix.group2
    @fix.save
  end
  
  after do
    @fix.destroy!
    QueuedEmail.all.each { |e| e.destroy! }
    QueuedSMS.all.each { |s| s.destroy! }
  end
end

describe 'Alerts on Offering objects' do
  behaves_like "a fixture test"
  
  it 'should have a change_alert method' do
    @fix.offering.should.respond_to?(:change_alert)
  end
  
  it 'should produce one alert email for each subscribed timetable' do
    @fix.offering.change_alert
    ems = QueuedEmail.all
    ems.size.should.equal 2
  end
  
  it 'should produce alert emails with the correct recipient' do
    @fix.offering.change_alert
    ems = QueuedEmail.all
    ems.each do |e|
      e.recipient.should.equal @fix.user.email
    end
  end
  
  it 'should produce alert emails with the correct subject' do
    @fix.offering.change_alert
    ems = QueuedEmail.all
    ems.each do |e|
      e.subject.should.include?(@fix.course.code)
    end
  end
end

describe 'Alerts on Series objects' do
  behaves_like "a fixture test"
  
  it 'should have a change_alert method' do
    @fix.series.should.respond_to?(:change_alert)
  end
  
  it 'should produce one alert email for each subscribed timetable' do
    @fix.series.change_alert
    ems = QueuedEmail.all
    ems.size.should.equal 2
  end
  
  it 'should produce alert emails with the correct recipient' do
    @fix.series.change_alert
    ems = QueuedEmail.all
    ems.each do |e|
      e.recipient.should.equal @fix.user.email
    end
  end
  
  it 'should produce alert emails with the correct subject' do
    @fix.series.change_alert
    ems = QueuedEmail.all
    ems.each do |e|
      e.subject.should.include?("#{@fix.course.code} #{@fix.series.name}")
    end
  end
end

describe 'Alerts on Group objects' do
  behaves_like "a fixture test"
  
  it 'should have a change_alert method' do
    @fix.group.should.respond_to?(:change_alert)
  end
  
  it 'should produce one alert email for each subscribed timetable' do
    @fix.group.change_alert
    ems = QueuedEmail.all
    ems.size.should.equal 1
    @fix.group2.change_alert
    ems = QueuedEmail.all
    ems.size.should.equal 2
  end
  
  it 'should produce SMS alerts on enabled timetables' do
    @fix.group.change_alert
    @fix.group2.change_alert
    sms = QueuedSMS.all
    sms.size.should.equal 1
  end
  
  it 'should produce SMS alerts with the group name inside' do
    @fix.group.change_alert
    @fix.group2.change_alert
    sms = QueuedSMS.first
    sms.text.should.include?("#{@fix.course.code} #{@fix.series.name}#{@fix.group2.name}")
  end
  
  it 'should produce alert emails with the correct recipient' do
    @fix.group.change_alert
    ems = QueuedEmail.all
    ems.each do |e|
      e.recipient.should.equal @fix.user.email
    end
  end
  
  it 'should produce alert emails with the correct subject' do
    @fix.group.change_alert
    ems = QueuedEmail.all
    ems.each do |e|
      e.subject.should.include?("#{@fix.course.code} #{@fix.series.name}#{@fix.group.name}")
    end
  end
end
