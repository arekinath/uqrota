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
    property :salt, String
    property :mobile, String
    
    property :last_login, DateTime
    
    property :admin, Boolean, :default => false
    
    has n, :user_semesters, :constraint => :destroy
    alias :old_usems :user_semesters
    
    has n, :api_sessions, 'APISession', :constraint => :destroy
    
    has n, :plan_boxes, :through => :user_semesters
    has n, :notifications, :constraint => :destroy
    
    include JSON::Serializable
    json_attrs :email, :mobile, :last_login, :admin
    json_children :user_semesters, :notifications
    
    def password=(pw)
      self.salt = Digest::SHA1.hexdigest(File.new("/dev/urandom").read(500)).slice(0,10)
      4096.times {
        pw = Digest::SHA1.hexdigest(self.salt + Digest::SHA1.hexdigest(pw))
      }
      self.password_sha1 = pw
    end
    
    def user_semesters
      self.old_usems.sort { |us| us.semester.id }
    end
    
    def is_password?(pw)
      4096.times {
        pw = Digest::SHA1.hexdigest(self.salt + Digest::SHA1.hexdigest(pw))
      }
      self.password_sha1 == pw
    end
    
    def owned_by?(user)
      self == user
    end
  end
  
  class UserSemester
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean
    
    belongs_to :user
    belongs_to :semester
    
    has n, :plan_boxes, :constraint => :destroy, :order => [:id.asc]
    has n, :timetables, :constraint => :destroy, :order => [:id.asc]
    
    def owned_by?(user)
      self.user == user
    end
    
    include JSON::Serializable
    json_attrs :visible
    json_parents :user, :semester
    json_children :plan_boxes, :timetables
  end
  
  class PlanBox
    include DataMapper::Resource
    
    property :id, Serial
    property :title, String, :length => 128
    
    belongs_to :user_semester
    has n, :course_selections, :constraint => :destroy, :order => [:id.asc]
    
    def owned_by?(user)
      self.user_semester.user == user
    end
    
    include JSON::Serializable
    json_attrs :title
    json_children :course_selections
    json_parents :user_semester
  end
  
  class Timetable
    include DataMapper::Resource
    
    property :id, Serial
    
    belongs_to :user_semester
    has n, :sharing_links, :constraint => :destroy
    
    has n, :group_selections, :constraint => :destroy
    has n, :series_selections, :constraint => :destroy
    
    def owned_by?(user)
      self.user_semester.user == user
    end
    
    def course_selections
      self.user_semester.plan_boxes.course_selections
    end
    
    include JSON::Serializable
    json_children :course_selections, :group_selections, :series_selections
    json_parents :user_semester
  end
  
  class CourseSelection
    include DataMapper::Resource
    
    property :id, Serial
    
    belongs_to :course
    belongs_to :plan_box
    
    has n, :group_selections, :constraint => :destroy
    has n, :series_selections, :constraint => :destroy
    has n, :hidden_sessions, :constraint => :destroy
    
    def owned_by?(user)
      self.plan_box.user_semester.user == user
    end
    
    include JSON::Serializable
    json_attrs :course
    json_children :group_selections, :series_selections, :hidden_sessions
    json_parents :plan_box
  end
  
  class SeriesSelection
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean, :default => true
    
    belongs_to :course_selection
    belongs_to :timetable
    
    belongs_to :timetable_series
    alias :series :timetable_series
    alias :series= :timetable_series=
    belongs_to :selected_group, 'TimetableGroup'
    
    def owned_by?(user)
      self.timetable.user_semester.user == user
    end
    
    include JSON::Serializable
    json_attrs :visible, :series, :selected_group
    json_parents :course_selection, :timetable
  end
  
  class HiddenSession
    include DataMapper::Resource
    
    property :id, Serial
    
    belongs_to :course_selection
    belongs_to :timetable
    
    belongs_to :timetable_session
    alias :session :timetable_session
    alias :session= :timetable_session=
    
    def owned_by?(user)
      self.timetable.user_semester.user == user
    end
    
    include JSON::Serializable
    json_attrs :session
    json_parents :course_selection, :timetable
  end
  
  class GroupSelection
    include DataMapper::Resource
    
    property :id, Serial
    property :visible, Boolean, :default => true
    
    belongs_to :course_selection
    belongs_to :timetable
    
    belongs_to :timetable_group
    alias :group :timetable_group
    alias :group= :timetable_group=
    
    def owned_by?(user)
      self.timetable.user_semester.user == user
    end
    
    include JSON::Serializable
    json_attrs :visible, :group
    json_parents :course_selection, :timetable
  end
  
  class TimetableSeries
    has n, :series_selections, :constraint => :protect
  end
  
  class TimetableGroup
    has n, :series_selections, :constraint => :protect
    has n, :group_selections, :constraint => :protect
  end
  
  class TimetableSession
    has n, :hidden_sessions, :constraint => :protect
  end
  
  class Course
    has n, :course_selections, :constraint => :protect
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
    
    has n, :logs, 'SharingLog', :constraint => :destroy
    belongs_to :timetable
    
    include JSON::Serializable
    json_key :hashcode
    json_attrs :uses_total, :uses_left, :allows_feed, :allows_copy, :expiry, :active
    json_children :logs
    json_parents :timetable
    
    def owned_by?(user)
      self.timetable.user_semester.user == user
    end
    
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
    
    def owned_by?(user)
      self.sharing_link.user == user
    end
    
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
    
    def owned_by?(user)
      self.user == user
    end
    
    include JSON::Serializable
    json_attrs :when, :target, :description, :login_count
    json_parent :user
  end
  
end