require File.expand_path("../../lib/config", __FILE__)

Rota::Config['database']['uri'] = 'sqlite::memory:'

require 'rota/model'
require 'rota/fetcher'

Rota.setup_and_finalize

require 'rubygems'

require 'dm-migrations'
DataMapper.auto_migrate!

require 'bacon'

include Rota

describe 'List fetchers' do

  it 'should fetch the course & timetable info page' do
    agent, page = Fetcher::SInet::tt_page()
    text = page.parser.text
    text.should.include?('Course & Timetable Info')
    text.should.include?('Search for courses by selecting')
  end
  
  it 'should fetch the undergrad plpp' do
    agent, page = Program.fetch_list
    text = page.parser.text
    text.should.include?('Undergraduate Program')
    text.should.include?('Science')
  end
  
  it 'should fetch the semesters list' do
    agent, page = Semester.fetch_list
    src = page.parser.to_s
    src.should.include?('Semester 1')
    src.should.include?('Summer Semester')
  end
  
  it 'should fetch the buildings list' do
    agent, page = Building.fetch_list
    text = page.parser.text
    text.should.include?('Forgan Smith')
    text.should.include?('Duhig')
  end
  
end
