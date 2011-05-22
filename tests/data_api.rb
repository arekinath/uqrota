# Require config, but in way that it won't ever be included twice
$:<< File.expand_path("../../lib/", __FILE__)
require 'config'
$:.pop

Rota::Config['database']['uri'] = 'yaml:tests/fixtures/apitests'

require 'rota/model'
require 'rota/fetcher'
require 'rubygems'

require 'dm-migrations'

require 'rack/test'

require 'bacon'
require 'fixtures'
require 'app'
require 'json'

include Rota

class Bacon::Context
  include Rack::Test::Methods
end

describe 'Data API' do  
  def app
    RotaApp
  end
  
  it 'should return the semester list as JSON' do
    get '/semesters.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    body = JSON.parse(last_response.body)
    body.is_a?(Array).should.be.true
    ids = body.collect { |h| h["id"] }
    ids.should.include?(6080)
    ids.should.include?(6110)
    body.each do |sem|
      if sem['id'] == 6160
        sem['current'].should.equal true
      elsif sem['id'] == 6180
        sem['start_week'].should.equal 48
        sem['midsem_week'].should.equal 51
        sem['finish_week'].should.equal 6
        sem['current'].should.equal false
      end
    end
  end
  
  it 'should return the semester list as XML' do
    get '/semesters.xml'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/xml/
    body = last_response.body
    # verify the xml here
  end
  
  it 'should return details of an individual semester' do
    get '/semester/6160.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    sem = JSON.parse(last_response.body)
    sem.is_a?(Hash).should.be.true
    sem['start_week'].should.equal 30
    sem['midsem_week'].should.equal 39
    sem['finish_week'].should.equal 43
    sem['current'].should.equal true
  end
  
  it 'should return a list of offerings in a semester' do
    get '/semester/6120/offerings.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    lst = JSON.parse(last_response.body)
    lst.is_a?(Array).should.be.true
    lst.size.should.equal 1
    lst[0]['course']['code'].should.equal "AGRC1906C"
  end
  
  it 'should return a course as JSON' do
    get '/course/AGRC1906C.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    course = JSON.parse(last_response.body)
    course.is_a?(Hash).should.be.true
    course['units'].should.equal 2
    course['coordinator'].should.equal "Mr M. Pace"
    course['offerings'].size.should.equal 1
    course['offerings'][0]['id'].should.equal 1
  end
  
  it 'should return an offering as JSON' do
    get '/offering/1.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    o = JSON.parse(last_response.body)
    o.is_a?(Hash).should.be.true
    
    o['series'].size.should.equal 1
    s = o['series'][0]
    s['name'].should.equal 'C'
    s['groups'].size.should.equal 1
    g = s['groups'][0]
    g['sessions'].size.should.equal 1
    ss = g['sessions'][0]
    ss['events'].size.should.equal 14
    ss['events'][0]['id'].should.equal 1
    
    o['assessment_tasks'].size.should.equal 6
    o['assessment_tasks'][0]['name'].should.equal " Risk Assessment,Hazard ID, Legislation and the ACT"
  end
  
  
end
