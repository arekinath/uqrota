require 'rubygems'
require 'dm-core'
require 'dm-transactions'
require 'dm-constraints'
require 'digest/sha1'
require 'rota/datamodel'
require 'config'

DataMapper.setup(:default, Rota::Config['database']['uri'])
DataMapper::Model.raise_on_save_failure = true

module Rota
  class User
    include DataMapper::Resource
    
    property :email, String, :key => true, :length => 128
    property :password_sha1, String
    property :mobile, String
    
    property :last_login, DateTime
    
    property :admin, Boolean, :default => false
    
    has n, :semester_plans, :constraint => :destroy, :child_key => [:owner_email]
    has n, :timetables, :through => :semester_plans
    
    has n, :readables, 'Timetable', :through => Resource
    has n, :writeables, 'Timetable', :through => Resource
    
    def password=(pw)
      self.password_sha1 = User.hash_password(self.email + pw)
    end
    
    def is_password?(pw)
      self.password_sha1 == User.hash_password(self.email + pw)
    end
    
    # Hash a password for storage and comparison
    # Currently just uses sha-1
    def User.hash_password(pw)
      Digest::SHA1.hexdigest(pw)
    end
  end
  
  class SemesterPlan
    include DataMapper::Resource
    
    property :id, Serial
    
    property :name, String, :length => 256
    belongs_to :owner, 'User'
    belongs_to :semester
    has n, :courses, :through => Resource, :constraint => :skip
    
    has n, :timetables, :constraint => :destroy
  end
  
  class Timetable
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String, :length => 256
    
    property :alert_sms, Boolean, :default => false
    property :alert_email, Boolean, :default => true
    
    has 1, :owner, 'User', :through => :semester_plan
    
    has n, :readers, 'User', :through => Resource
    has n, :writers, 'User', :through => Resource
    
    has n, :shares, :constraint => :destroy
    
    belongs_to :semester_plan
    
    has n, :timetable_groups, :through => Resource, :constraint => :skip
    alias :groups :timetable_groups
    
    has n, :hidden_sessions, 'TimetableSession', :through => Resource, :constraint => :skip
  end
  
  class Share
    include DataMapper::Resource
    
    property :id, String, :key => true
    
    belongs_to :timetable
    property :rights, String
    property :expires, DateTime
    property :counter, Integer
    
    def Share.gen_id
      f = File.new('/dev/urandom')  
      Digest::SHA1.hexdigest(f.read(100))
    end
  end
end