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

describe 'The Login API' do  
  def app
    RotaApp
  end
  
  before do
    @fix = FixtureSet.new('tests/fixtures/user_api_test_data.yml')
    @fix.save
  end
  
  after do
    @fix.destroy!
  end
  
  it 'should be logged out by default' do
    get '/login.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    body = JSON.parse(last_response.body)
    body["logged_in"].should.equal false
  end
  
  it 'should reject an invalid user' do
    post '/login.json', {:email => 'blah@invalid.com', :password => 'invalid' }
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    body = JSON.parse(last_response.body)
    body["success"].should.equal false
  end
  
  it 'should reject an invalid password' do
    post '/login.json', {:email => 'user@user.com', :password => 'invalid' }
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    body = JSON.parse(last_response.body)
    body["success"].should.equal false
  end
  
  it 'should accept a valid login pair' do
    post '/login.json', {:email => 'user@user.com', :password => 'user1'}
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    body = JSON.parse(last_response.body)
    body["success"].should.equal true
  end
  
  it 'should return correct details from login.json after success' do
    post '/login.json', {:email => 'user@user.com', :password => 'user1'}
    last_response.should.be.ok
    get '/login.json'
    last_response.should.be.ok
    last_response.headers['Content-Type'].should.match /^text\/javascript/
    body = JSON.parse(last_response.body)
    body["logged_in"].should.equal true
    body["email"].should.equal "user@user.com"
  end
  
  it 'should allow users to log out' do
    post '/login.json', {:email => 'user@user.com', :password => 'user1'}
    last_response.should.be.ok
    get '/login.json'
    last_response.should.be.ok
    JSON.parse(last_response.body)["logged_in"].should.equal true
    post '/logout.json'
    last_response.should.be.ok
    JSON.parse(last_response.body)["success"].should.equal true
    get '/login.json'
    last_response.should.be.ok
    body = JSON.parse(last_response.body)
    body["logged_in"].should.equal false
    body["email"].should.be.nil?
  end
end
