require 'rubygems'
require 'config'
require 'rota/model'

module Rota
  
  class User
    property :use_facebook, Boolean
    property :fb_uid, String, :length => 128
    property :fb_access_token, String, :length => 256
    property :fb_expires, DateTime
  end
  
end