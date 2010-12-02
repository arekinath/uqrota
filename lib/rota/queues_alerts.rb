require 'rota/model'
require 'rubygems'
require 'dm-core'
require 'digest/sha1'
require 'utils/sms'
require 'net/smtp'
require 'date'

module Rota
  module Model
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
        sender = Utils::SMSSender.new(Setting.get('sms_user').value, Setting.get('sms_pass').value)
        sender.send(:recipient => self.recipient, :text => self.text, :sender => Setting.get('sms_from').value)
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
        msg = <<ENDMSG
From: UQRota <noreply@uqrota.net>
To: #{self.recipient}
Subject: #{self.subject}
Date: #{Time.now.to_s}

#{self.body}
ENDMSG
        Net::SMTP.start('milky.rijidij.org', 25, 'mail.uqrota.net', 'ycd', 'ycdrox', :plain) do |smtp|
          smtp.send_message msg, 'noreply@uqrota.net', self.recipient
        end

        self.destroy!
      end
    end

    class Course
      def change_alert
        ChangelogEntry.make("updater", "#{self.code} added/removed course series")
        
        tts = Array.new
        self.series.each { |s| s.groups.each { |g| g.timetables.each { |tt| tts << tt if not tts.include?(tt) } } }

        tts.each do |t|
          srs = "#{self.code}"
          if t.alert_sms
            sms = QueuedSMS.new
            sms.recipient = t.user.mobile
            sms.text = "UqRota: #{srs} has added/removed entire course series. Pls check site for details"
            sms.save
          end

          if t.alert_email
            em = QueuedEmail.new
            em.recipient = t.user.email
            em.subject = "UqRota alteration alert: #{srs}"
            em.body = <<END
Hi, this is the UqRota timetable monitor.

You have an alert set on the course #{srs}, which has been triggered. This means
that an entire course series has changed (eg, the course didn't have tutorials before but 
does now.) Please check the site for further details about the alteration.

Regards,
UqRota
END
            em.save
          end
        end
      end
    end

    class Series
      def change_alert
        ChangelogEntry.make("updater", "#{self.course.code} #{self.name} added/removed groups")
        
        tts = Array.new
        self.groups.each { |g| g.timetables.each { |tt| tts << tt if not tts.include?(tt) } }

        tts.each do |t|
          srs = "#{self.course.code} #{self.name}"
          if t.alert_sms
            sms = QueuedSMS.new
            sms.recipient = t.user.mobile
            sms.text = "UqRota: #{srs} has added/removed groups. Pls check site for details"
            sms.save
          end

          if t.alert_email
            em = QueuedEmail.new
            em.recipient = t.user.email
            em.subject = "UqRota alteration alert: #{srs}"
            em.body = <<END
Hi, this is the UqRota timetable monitor.

You have an alert set on the timetable series #{srs}, which has been triggered. This
means that groups (like T3 and T4 in a tutorial series) have been added or removed.
Please check the site for further details about the alteration.

Regards,
UqRota
END
            em.save
          end
        end
      end
    end

    class Group
      def change_alert
        ChangelogEntry.make("updater", "#{self.series.course.code} #{self.series.name}#{self.name} changed details")
        
        self.timetables.each do |t|
          grp = "#{self.series.course.code} #{self.series.name}#{self.name}"
          if t.alert_sms
            sms = QueuedSMS.new
            sms.recipient = t.user.mobile
            sms.text = "UqRota: #{grp} has changed in sinet. Pls check site for details"
            sms.save
          end

          if t.alert_email
            em = QueuedEmail.new
            em.recipient = t.user.email
            em.subject = "UqRota alteration alert: #{grp}"
            em.body = <<END
Hi, this is the UqRota timetable monitor.

You have an alert set on the timetable group #{grp}, which has been triggered. Please 
check the site for further details about the alteration.

Regards,
UqRota
END
            em.save
          end
        end
      end
    end
  end
end
