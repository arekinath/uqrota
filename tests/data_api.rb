# Require config, but in way that it won't ever be included twice
$:<< File.expand_path("../../lib/", __FILE__)
require 'config'
$:.pop

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rota/fetcher'
require 'rubygems'

require 'dm-migrations'
DataMapper.auto_migrate!

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
  
  before do
    @fix = FixtureSet.new('tests/fixtures/data_api_test_data.yml')
    @fix.save
  end
  
  it 'should return the semester list' do
    get '/semesters.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    body = JSON.parse(last_response.body)
    body.is_a?(Hash).should.be.true
    body["semesters"].is_a?(Array).should.be.true
    body["semesters"].include?({"id" => 6020}).should.be.true
    body["semesters"].include?({"id" => 6080, "current" => true}).should.be.true
  end
end
