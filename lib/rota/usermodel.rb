require 'rubygems'
require 'dm-core'
require 'dm-transactions'
require 'dm-constraints'
require 'digest/sha1'
require 'rota/datamodel'
require 'config'
require 'utils/json'

DataMapper.setup(:default, Rota::Config['database']['uri'])
DataMapper::Model.raise_on_save_failure = true

module Rota
  class User
    include DataMapper::Resource
    
    property :id, Serial
    property :email, String, :length => 128, :unique => true, :index => true
    property :password_sha1, String
    property :mobile, String
    
    property :last_login, DateTime
    
    property :admin, Boolean, :default => false
    
    has n, :plan_boxes
    has n, :notifications
    
    include JSON::Serializable
    json_attrs :email, :mobile, :last_login, :admin
    json_children :plan_boxes, :notifications
    
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
    has n, :courses, :through => Resource
    has n, :timetables
    
    include JSON::Serializable
    json_attrs :title
    json_children :courses, :timetables
    json_parents :user, :semester
  end
  
  class Timetable
    include DataMapper::Resource
    
    property :id, Serial
    
    belongs_to :plan_box
    has n, :course_selections, :required => false
    has n, :sharing_links, :required => false
    
    include JSON::Serializable
    json_children :course_selections
    json_parents :plan_box
  end
  
  class CourseSelection
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean, :default => true
    
    belongs_to :course
    belongs_to :timetable
    
    has n, :group_selections
    has n, :series_selections
    
    include JSON::Serializable
    json_attrs :visible, :course
    json_children :group_selections, :series_selections
    json_parents :timetable
  end
  
  class SeriesSelection
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean, :default => true
    
    belongs_to :course_selection
    belongs_to :timetable_series
    alias :series :timetable_series
    belongs_to :selected_group, 'TimetableGroup'
    
    include JSON::Serializable
    json_attrs :visible, :series, :selected_group
    json_parents :course_selection
  end
  
  class GroupSelection
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean, :default => true
    
    belongs_to :course_selection
    belongs_to :timetable_group
    alias :group :timetable_group
    alias :group= :timetable_group=
    
    include JSON::Serializable
    json_attrs :visible, :group
    json_parents :course_selection
  end
  
  class TimetableSeries
    has n, :series_selections, :required => false
  end
  
  class TimetableGroup
    has n, :series_selections, :required => false
    has n, :group_selections, :required => false
  end
  
  class Course
    has n, :plan_boxes, :through => Resource
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
    
    include JSON::Serializable
    json_key :hashcode
    json_attrs :uses_total, :uses_left, :allows_feed, :allows_copy, :expiry, :active
    json_children :logs
    json_parents :timetable
    
    def initialize(*k)
      super(*k)
      while self.hashcode.nil? or SharingLink.all(:hashcode => self.hashcode).size > 0
        bytes = File.new("/dev/urandom").read(500)
        self.hashcode = Digest::SHA1.hexdigest(bytes)
      end
    end
  end
  
  class APISession
    include DataMapper::Resource
    
    property :hashcode, String, :length => 45, :key => true
    
    property :created, DateTime
    property :last_used, DateTime
    
    property :logged_in, Boolean, :default => false
    belongs_to :user, :required => false
    
    property :secret, String, :length => 45
    
    include JSON::Serializable
    json_key :hashcode
    json_attrs :created, :last_used, :logged_in, :user, :secret
    
    def initialize(*k)
      super(*k)
      while self.hashcode.nil? or APISession.all(:hashcode => self.hashcode).size > 0
        bytes_hc = File.new("/dev/urandom").read(500)
        bytes_sec = File.new("/dev/urandom").read(500)
        self.hashcode = Digest::SHA1.hexdigest(bytes_hc)
        self.secret = Digest::SHA1.hexdigest(bytes_sec)
      end
      self.created = Time.now
      self.last_used = Time.now
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
    
    include JSON::Serializable
    json_attrs :ip, :when, :email
    json_parent :sharing_link
  end
  
  class Notification
    include DataMapper::Resource
    
    property :id, Serial
    property :when, DateTime
    property :target, String, :length => 128
    property :description, Text
    
    property :login_count, Integer
    
    belongs_to :user
    
    include JSON::Serializable
    json_attrs :when, :target, :description, :login_count
    json_parent :user
  end
  
end