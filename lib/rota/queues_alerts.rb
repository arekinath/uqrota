require 'rota/model'
require 'rota/messages'
require 'rubygems'
require 'dm-core'
require 'digest/sha1'
require 'utils/sms'
require 'net/smtp'
require 'date'
require 'config'
require 'json'

module Rota

  class ChangelogEntry
    include DataMapper::Resource
    
    property :id, Serial
    property :source, String, :length => 100
    property :objkey, String, :length => 500
    property :created, DateTime, :index => true
    property :uuid, String, :length => 100, :index => true
    
    include JSON::Serializable
    json_attrs :source, :targets, :message, :created
    
    def message; Message.find(self.uuid); end
    def message=(m); self.uuid = m.uuid; end
    
    def targets
      k = JSON.parse(self.objkey)
      h = {}
      k.each { |key, val|
        if val.is_a?(Hash) and val['class'] and val['key']
          h[key] = Rota::const_get(val['class']).get(*(val['key']))
        else
          h[key] = val
        end
      }
      return h
    end
    
    def targets=(ts)
      k = {}
      ts.each do |tk, tv|
        if tv.respond_to?(:key)
          kk = {}
          kk['class'] = tv.class.name.split("::").last
          kk['key'] = tv.key
          k[tk] = kk
        else
          k[tk] = tv
        end
      end
      self.objkey = k.to_json
    end
    
    def ==(other)
      (self.targets == other.targets and 
        self.source == other.source and 
        self.message == other.message and
        (self.created - other.created) < Rational(5,60*24))
    end
    
    def ChangelogEntry.make(source, message, targets)
      e = ChangelogEntry.new
      e.source = source
      e.targets = targets
      e.created = DateTime.now
      e.uuid = message.uuid
      
      # validate the contents of the targets hash
      if not message.is_valid?(targets)
        throw Exception.new("Target hash is not valid for the given message")
      end
      
      # check whether this is a dupe
      ChangelogEntry.first(50, :uuid => e.uuid, :order => [:created.desc]).each do |c|
        if c == e
          return
        end
      end
      
      e.save
    end
  end
  
  class QueuedSMS
    include DataMapper::Resource
    
    property :id, Serial
    property :recipient, String
    property :text, String, :length => 320
    
    def send
      sender = Utils::SMSSender.new(Rota::Config['sms']['username'], Rota::Config['sms']['password'])
      sender.send(:recipient => self.recipient, :text => self.text, :sender => Rota::Config['sms']['from'])
      self.destroy!
    end
  end
  
  class QueuedEmail
    include DataMapper::Resource
    
    property :id, Serial
    property :recipient, String, :length => 200
    property :subject, String, :length => 200
    property :body, Text
    
    def send
      origin = Rota::Config['smtp']['from']
      msg = <<ENDMSG
From: UQRota <#{origin}>
To: #{self.recipient}
Subject: #{self.subject}
Date: #{Time.now.to_s}

#{self.body}
ENDMSG
      smtpc = Rota::Config['smtp']
      
      Net::SMTP.start(smtpc['host'], smtpc['port'].to_i, 'mail.uqrota.net', smtpc['user'], smtpc['password'], smtpc['user'].nil? ? nil : :plain) do |smtp|
        smtp.send_message msg, origin, self.recipient
      end
      
      self.destroy!
    end
  end
end
