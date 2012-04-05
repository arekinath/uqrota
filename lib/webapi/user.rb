require 'rubygems'
require 'config'
require 'rota/model'
require 'rota/queues_alerts'
require 'rota/fetcher'
require 'rota/temporal'
require 'rota/messages'
require 'utils/xml'
require 'webapi/common'
require 'sinatra/base'
require 'sinatra/namespace'
require 'digest/sha1'
require 'base64'

class << Sinatra::Base
  def http_options path,opts={}, &blk
    route 'OPTIONS', path, opts, &blk
  end
end
Sinatra::Delegator.delegate :http_options 

class UserService < Sinatra::Base
  register Sinatra::Namespace
  
end
