require File.expand_path("../../lib/config", __FILE__)

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rota/fetcher'
require 'rubygems'

require 'dm-migrations'
DataMapper.auto_migrate!

require 'bacon'

include Rota::Model

describe 'The fetcher' do
  before do
    @f = Rota::Fetcher.new
  end

  it 'should fetch the course & timetable info page' do
    agent, page = @f.get_tt_page
    text = page.parser.text
    text.should.include?('Course & Timetable Info')
    text.should.include?('Search for courses by selecting')
  end
  
  it 'should fetch the undergrad plpp' do
    agent, page = @f.get_pgm_list_page
    text = page.parser.text
    text.should.include?('Undergraduate Program')
    text.should.include?('Science')
  end
end
