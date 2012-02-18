require 'rota/model'
require 'rubygems'
require 'dm-core'
require 'digest/sha1'
require 'utils/sms'
require 'net/smtp'
require 'date'
require 'config'

module Rota
  class ChangelogEntry
    include DataMapper::Resource
    
    property :id, Serial
    property :source, String, :length => 100
    property :created, DateTime
    property :description, String, :length => 256
    
    def ChangelogEntry.make(source, desc)
      e = ChangelogEntry.new
      e.source = source
      e.created = DateTime.now
      e.description = desc
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
  
  class Offering
    def change_alert
      ChangelogEntry.make("updater", "#{self.course.code} added/removed course series")
   
    end
  end
  
  class TimetableSeries
    def change_alert
      ChangelogEntry.make("updater", "#{self.offering.course.code} #{self.name} added/removed groups")
      
      
    end
  end
  
  class TimetableGroup
    def change_alert
      code = self.series.offering.course.code
      ChangelogEntry.make("updater", "#{code} #{self.series.name}#{self.name} changed details")
      
    end
  end
end
