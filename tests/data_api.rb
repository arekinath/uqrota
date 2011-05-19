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
        sem['is_current?'].should.equal true
      elsif sem['id'] == 6180
        sem['start_week'].should.equal 48
        sem['midsem_week'].should.equal 51
        sem['finish_week'].should.equal 6
        sem['is_current?'].should.equal false
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
    sem['is_current?'].should.equal true
  end
  
  it 'should return a list of offerings in a semester' do
    get '/semester/6120/offerings.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    sem = JSON.parse(last_response.body)
    sem.is_a?(Hash).should.be.true
    sem['id'].should.equal 6120
    o = sem['offerings']
    o.is_a?(Array).should.be.true
    o.size.should.equal 1
    o[0]['course']['code'].should.equal "AGRC1906C"
  end
end
