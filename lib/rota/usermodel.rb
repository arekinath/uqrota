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
    
    has n, :plan_boxes
    has n, :notifications
    
    def password=(pw)
      self.password_sha1 = User.hash_password(self.email + pw)
    end
    
    def is_password?(pw)
      self.password_sha1 == User.hash_password(self.email + pw)
    end
    
    def sharing_links
      self.plan_boxes.timetables.sharing_links
    end
    
    # Hash a password for storage and comparison
    # Currently just uses sha-1
    def User.hash_password(pw)
      Digest::SHA1.hexdigest(pw)
    end
  end
  
  class PlanBox
    include DataMapper::Resource
    
    property :id, Serial
    property :title, String, :length => 128
    
    belongs_to :user
    belongs_to :semester
    has n, :courses
    has n, :timetables
    
    has n, :plan_boxes
  end
  
  class Timetable
    include DataMapper::Resource
    
    property :id, Serial
    
    belongs_to :plan_box
    has n, :course_selections
    has n, :sharing_links
  end
  
  class CourseSelection
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean, :default => true
    
    belongs_to :course
    belongs_to :timetable
    
    has n, :group_selections
    has n, :series_selections
  end
  
  class SeriesSelection
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean, :default => true
    
    belongs_to :course_selection
    belongs_to :timetable_series
    alias :series :timetable_series
    belongs_to :selected_group, 'TimetableGroup'
  end
  
  class GroupSelection
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean, :default => true
    
    belongs_to :course_selection
    belongs_to :timetable_group
    alias :group :timetable_group
    alias :group= :timetable_group=
  end
  
  class TimetableSeries
    has n, :series_selections
  end
  
  class TimetableGroup
    has n, :series_selections
    has n, :group_selections
  end
  
  class Course
    has n, :plan_boxes
  end
  
  class SharingLink
    include DataMapper::Resource
    
    property :hashcode, String, :length => 40, :key => true
    
    property :uses_total, Integer
    property :uses_left, Integer
    
    property :allows_feed, Boolean
    property :allows_copy, Boolean
    
    property :expiry, DateTime
    
    property :active, Boolean
    
    has n, :logs, 'SharingLog'
    belongs_to :timetable
    
    def initialize(*k)
      super(*k)
      while self.hashcode and SharingLink.all(:hashcode => self.hashcode).size > 0
        bytes = File.new("/dev/urandom").read(500)
        self.hashcode = Digest::SHA1.hexdigest(bytes)
      end
    end
  end
  
  class APISession
    include DataMapper::Resource
    
    property :hashcode, String, :length => 40, :key => true
    
    property :created, DateTime
    property :last_used, DateTime
    
    property :logged_in, Boolean, :default => false
    belongs_to :user, :required => false
    
    property :secret, String, :length => 40
    
    def initialize(*k)
      super(*k)
      while self.hashcode and APISession.all(:hashcode => self.hashcode).size > 0
        bytes_hc = File.new("/dev/urandom").read(500)
        bytes_sec = File.new("/dev/urandom").read(500)
        self.hashcode = Digest::SHA1.hexdigest(bytes_hc)
        self.secret = Digest::SHA1.hexdigest(bytes_sec)
      end
    end
    
    def self.from_session(sess)
      s = nil
      if sess['apisession']
        s = self.first(:hashcode => sess['apisession'])
      end
      if s.nil?
        s = self.new
        s.save
        sess['apisession'] = s.hashcode
      end
      return s
    end
  end
  
  class SharingLog
    include DataMapper::Resource
    
    property :id, Serial
    property :ip, String, :length => 128
    property :when, DateTime
    property :email, String, :length => 128
    
    belongs_to :sharing_link
  end
  
  class Notification
    include DataMapper::Resource
    
    property :id, Serial
    property :when, DateTime
    property :target, String, :length => 128
    property :description, Text
    
    property :login_count, Integer
    
    belongs_to :user
  end
  
end