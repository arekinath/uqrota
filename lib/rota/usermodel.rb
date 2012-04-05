require 'rubygems'
require 'dm-core'
require 'dm-transactions'
require 'dm-constraints'
require 'digest/sha1'
require 'base64'
require 'openssl'
require 'rota/datamodel'
require 'rota/queues_alerts'
require 'config'
require 'utils/json'
require 'rota/querylang'

module Rota

  class User
    include DataMapper::Resource
    
    property :id, Serial
    property :public_key, String, :length => 2048, :unique => true, :index => true
    property :name, String
    property :approved, Boolean
    
    has n, :message_filters, :constraint => :destroy
    
    def key
        if @keycache.nil?
            @keycache = OpenSSL::PKey::RSA.new(self.public_key)
        end
        @keycache
    end
    
    def encrypt(string)
        Base64.encode64(self.key.public_encrypt(string))
    end
    
    def decrypt(string)
        self.key.public_decrypt(Base64.decode64(string))
    end
    
    include JSON::Serializable
    json_attrs :public_key, :name, :approved
  end
  
  class MessageFilter
    include DataMapper::Resource
    
    property :id, Serial
    property :source, Text
    property :compiled, Text
    property :push_endpoint, String, :length => 256, :required => false
    
    belongs_to :user
    has n, :notifications, :constraint => :destroy
    
    def filter=(code)
      self.source = code
      parser = MessageQuery::Parser.new
      tree = parser.parse(code)
      if tree.nil?
        puts parser.failure_reason.inspect
      else
        self.compiled = tree.compile
        @filter = eval(self.compiled)
      end
    end
    
    def filter
      if @filter.nil?
        @filter = eval(self.compiled)
      else
        @filter
      end
    end
  end
  
  class Notification
    include DataMapper::Resource
    
    property :id, Serial
    belongs_to :message_filter
    belongs_to :changelog_entry
    
    after :save, :notify
    
    def notify
      unless self.message_filter.push_endpoint.nil?
        # TODO: push notification code here
      end
    end
  end
  
  class ChangelogEntry
    has n, :notifications, :constraint => :destroy
    
    after :save, :notify
    
    def notify
      MessageFilter.all.each do |mf|
        if mf.filter.call(self) == true
          n = Notification.new
          n.message_filter = mf
          n.changelog_entry = self
          n.save
        end
      end
    end
  end
  
end
