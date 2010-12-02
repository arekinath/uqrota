require 'rota/model'
require 'rota/queues_alerts'

require 'rubygems'
require 'dm-core'
require 'RedCloth'

module Rota
  module Model
    class UserQuestion
      include DataMapper::Resource
      
      property :id, Serial
      property :user, String
      property :user_email, String
      property :created, DateTime
      property :question, String, :length => 8192
      property :answer, String, :length => 8192
      property :answered, Boolean
      property :published, Boolean
      
      def alert
        em = QueuedEmail.new
        em.recipient = "bugs@uqrota.net"
        em.subject = "Bug report from #{self.user_email}"
        em.body = <<END
Bug report:

view at: http://uqrota.net/bugs/#{self['id']}

From: #{user_email}
Created: #{created}

Question:
#{question}
END
        em.save
        em.send
      end
      
      def provide_answer(newanswer)
        self.answer = newanswer
        self.answered = true
        em = QueuedEmail.new
        em.recipient = self.user_email
        em.subject = "Reply to UQRota bug/question ##{self['id']}"
        dt = (self.created+Rational(10,24)).strftime("%Y-%m-%d %H:%M")
        em.body = <<END
Hi, you posted the following question to the UQRota Q&A page on #{dt}:

> #{self.question.split("\n").join("\n> ")}

Your question has now been answered:

> #{self.answer.split("\n").join("\n> ")}

Thanks for using the Q&A system!
-UQRota
END
        em.save
        em.send
      end
    end
    
    class InstrumentCounter
      include DataMapper::Resource
      
      property :name, String, :length => 128, :key => true
      property :count, Integer, :default => 0
    end
    
    class WikiPage
      include DataMapper::Resource
      
      property :name, String, :length => 128, :key => true
      property :data, String, :length => 4096
      property :last_updated, DateTime
      
      alias :my_data= :data=
      def data=(newdata)
        self.my_data=(newdata)
        ChangelogEntry.make("wiki", "updated page #{self.name}")
        last_updated = DateTime.now
      end
      
      def html
        RedCloth.new(self.data).to_html
      end
    end
  end
end
