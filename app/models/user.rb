require 'danbooru/has_bit_flags'

class User < ApplicationRecord
  class Error < Exception ; end
  class PrivilegeError < Exception ; end

  module Levels
    BLOCKED = 10
    BASIC = 20
    GOLD = 30
    PLATINUM = 31
    ADMIN = 50
  end

  # Used for `before_filter :<role>_only`. Must have a corresponding `is_<role>?` method.
  Roles = Levels.constants.map(&:downcase) + [
    :anonymous,
    :banned,
    :verified,
    :moderator
  ]

  BOOLEAN_ATTRIBUTES = %w(
    is_banned
    has_mail
    receive_email_notifications
    always_resize_images
    hide_deleted_posts
    enable_auto_complete
    show_deleted_children
    has_saved_searches
  )

  include Danbooru::HasBitFlags
  has_bit_flags BOOLEAN_ATTRIBUTES, :field => "bit_prefs"

  attr_accessor :password, :old_password
  # attr_accessible :dmail_filter_attributes, :password, :old_password, :password_confirmation, :password_hash, :email, :last_logged_in_at, :last_forum_read_at, :has_mail, :receive_email_notifications, :comment_threshold, :always_resize_images, :blacklisted_tags, :name, :ip_addr, :time_zone, :default_image_size, :per_page, :hide_deleted_posts, :enable_auto_complete, :custom_style, :show_deleted_children, :as => [:moderator, :gold, :platinum, :member, :anonymous, :default, :admin]
  # attr_accessible :level, :as => :admin

  validates :name, user_name: true, on: :create
  validates_uniqueness_of :email, :case_sensitive => false, :if => lambda {|rec| rec.email.present? && rec.email_changed? }
  validates_length_of :password, :minimum => 5, :if => lambda {|rec| rec.new_record? || rec.password.present?}
  validates_inclusion_of :default_image_size, :in => %w(large original)
  validates_inclusion_of :per_page, :in => 1..100
  validates_confirmation_of :password
  validates_presence_of :email, :if => lambda {|rec| rec.new_record? && Danbooru.config.enable_email_verification?}
  validates_presence_of :comment_threshold
  validate :validate_ip_addr_is_not_banned, :on => :create
  before_validation :normalize_blacklisted_tags
  before_validation :set_per_page
  before_validation :normalize_email
  before_create :encrypt_password_on_create
  before_update :encrypt_password_on_update
  before_create :initialize_default_boolean_attributes
  after_save :update_cache
  after_update :update_remote_cache
  before_create :promote_to_admin_if_first_user
  before_create :customize_new_user
  has_many :memberships
  has_many :boorus, through: :memberships
  has_many :feedback, :class_name => "UserFeedback", :dependent => :destroy
  has_many :posts, :foreign_key => "uploader_id"
  has_many :post_votes
  has_many :bans, lambda {order("bans.id desc")}
  has_one :recent_ban, lambda {order("bans.id desc")}, :class_name => "Ban"
  has_one :dmail_filter
  has_one :token_bucket
  has_many :note_versions, :foreign_key => "updater_id"
  has_many :dmails, lambda {order("dmails.id desc")}, :foreign_key => "owner_id"
  has_many :saved_searches
  has_many :forum_posts, lambda {order("forum_posts.created_at")}, :foreign_key => "creator_id"
  has_many :user_name_change_requests, lambda {visible.order("user_name_change_requests.created_at desc")}
  after_update :create_mod_action
  accepts_nested_attributes_for :dmail_filter

  module BanMethods
    def is_banned_or_ip_banned?
      return is_banned? || IpBan.is_banned?(CurrentUser.ip_addr)
    end

    def validate_ip_addr_is_not_banned
      if IpBan.is_banned?(CurrentUser.ip_addr)
        self.errors[:base] << "IP address is banned"
        return false
      end
    end

    def unban!
      self.is_banned = false
      save
    end

    def ban_expired?
      is_banned? && recent_ban.try(:expired?)
    end
  end

  module NameMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def name_to_id(name)
        Cache.get("uni:#{Cache.hash(name)}", 4.hours) do
          select_value_sql("SELECT id FROM users WHERE lower(name) = ?", name.mb_chars.downcase.tr(" ", "_").to_s)
        end
      end

      def id_to_name(user_id)
        Cache.get("uin:#{user_id}", 4.hours) do
          select_value_sql("SELECT name FROM users WHERE id = ?", user_id) || Danbooru.config.default_guest_name
        end
      end

      def find_by_name(name)
        where("lower(name) = ?", name.mb_chars.downcase.tr(" ", "_")).first
      end

      def id_to_pretty_name(user_id)
        id_to_name(user_id).gsub(/([^_])_+(?=[^_])/, "\\1 \\2")
      end

      def normalize_name(name)
        name.to_s.mb_chars.downcase.strip.tr(" ", "_").to_s
      end
    end

    def pretty_name
      name.gsub(/([^_])_+(?=[^_])/, "\\1 \\2")
    end

    def update_cache
      Cache.put("uin:#{id}", name)
      Cache.put("uni:#{Cache.hash(name)}", id)
    end

    def update_remote_cache
      if name_changed?
        Danbooru.config.other_server_hosts.each do |server|
          HTTParty.delete("http://#{server}/users/#{id}/cache", Danbooru.config.httparty_options)
        end
      end
    rescue Exception
      # swallow, since it'll be expired eventually anyway
    end
  end

  module PasswordMethods
    def bcrypt_password
      BCrypt::Password.new(bcrypt_password_hash)
    end

    def bcrypt_cookie_password_hash
      Digest::SHA1.hexdigest(bcrypt_password_hash)
    end

    def encrypt_password_on_create
      self.bcrypt_password_hash = User.bcrypt(User.salt_password(password))
    end

    def encrypt_password_on_update
      return if password.blank?
      return if old_password.blank?

      if bcrypt_password == User.salt_password(old_password)
        self.bcrypt_password_hash = User.bcrypt(User.salt_password(password))
        return true
      else
        errors[:old_password] = "is incorrect"
        return false
      end
    end

    def reset_password
      consonants = "bcdfghjklmnpqrstvqxyz"
      vowels = "aeiou"
      pass = ""

      6.times do
        pass << consonants[rand(21), 1]
        pass << vowels[rand(5), 1]
      end

      pass << rand(100).to_s
      update_column(:bcrypt_password_hash, User.bcrypt(User.salt_password(pass)))
      pass
    end

    def reset_password_and_deliver_notice
      new_password = reset_password()
      Maintenance::User::PasswordResetMailer.confirmation(self, new_password).deliver_now
    end
  end

  module AuthenticationMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def authenticate(name, pass)
        user = find_by_name(name)
        if user && user.bcrypt_password == salt_password(pass)
          user
        else
          nil
        end
      end

      def salt_password(pass)
        "#{Danbooru.config.password_salt}#{pass}"
      end

      def bcrypt(pass)
        BCrypt::Password.create(pass)
      end
    end
  end

  module FavoriteMethods
    def favorites
      Favorite.where("user_id % 100 = #{id % 100} and user_id = #{id}").order("id desc")
    end

    def clean_favorite_count?
      favorite_count < 0 || Kernel.rand(100) < [Math.log(favorite_count, 2), 5].min
    end

    def clean_favorite_count!
      update_column(:favorite_count, Favorite.for_user(id).count)
    end

    def add_favorite!(post)
      Favorite.add(post: post, user: self)
      clean_favorite_count! if clean_favorite_count?
    end

    def remove_favorite!(post)
      Favorite.remove(post: post, user: self)
    end
  end

  module LevelMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def system
        Danbooru.config.system_user
      end

      def level_hash
        return {
          "Member" => Levels::BASIC,
          "Gold" => Levels::GOLD,
          "Platinum" => Levels::PLATINUM,
          "Admin" => Levels::ADMIN
        }
      end

      def level_string(value)
        case value
        when Levels::BLOCKED
          "Banned"

        when Levels::BASIC
          "Basic"

        when Levels::GOLD
          "Gold"

        when Levels::PLATINUM
          "Platinum"

        when Levels::ADMIN
          "Admin"
        
        else
          ""
        end
      end
    end

    def promote_to!(new_level, options = {})
      UserPromotion.new(self, CurrentUser.user, new_level, options).promote!
    end

    def promote_to_admin_if_first_user
      return if Rails.env.test?

      if User.count == 0
        self.level = Levels::ADMIN
      else
        self.level = Levels::BASIC
      end
    end

    def customize_new_user
      Danbooru.config.customize_new_user(self)
    end

    def role
      level_string.downcase.to_sym
    end

    def level_string_was
      level_string(level_was)
    end

    def level_string(value = nil)
      User.level_string(value || level)
    end

    def is_anonymous?
      false
    end

    def is_member?
      Membership.where(booru_id: Booru.current.id, user_id: id).exists?
    end

    def is_blocked?
      is_banned?
    end

    def is_basic?
      level >= Levels::BASIC
    end

    def is_gold?
      level >= Levels::GOLD
    end

    def is_platinum?
      level >= Levels::PLATINUM
    end

    def is_moderator?
      is_admin? || Booru.current.memberships.where(user_id: id, is_moderator: true).exists?
    end

    def is_mod?
      is_moderator?
    end

    def is_admin?
      level >= Levels::ADMIN
    end

    def create_mod_action
      if level_changed?
        ModAction.log(%{"#{name}":/users/#{id} level changed #{level_string_was} -> #{level_string}})
      end
    end
    
    def set_per_page
      if per_page.nil? || !is_gold?
        self.per_page = Danbooru.config.posts_per_page
      end
      
      return true
    end

    def level_class
      "user-#{level_string.downcase}"
    end
  end

  module EmailMethods
    def is_verified?
      email_verification_key.blank?
    end

    def generate_email_verification_key
      self.email_verification_key = SecureRandom.urlsafe_base64(32)
    end

    def verify!(key)
      if email_verification_key == key
        self.update_column(:email_verification_key, nil)
      else
        raise User::Error.new("Verification key does not match")
      end
    end

    def normalize_email
      self.email = nil if email.blank?
    end
  end

  module BlacklistMethods
    def blacklisted_tag_array
      Tag.scan_query(blacklisted_tags)
    end

    def normalize_blacklisted_tags
      self.blacklisted_tags = blacklisted_tags.downcase if blacklisted_tags.present?
    end
  end

  module ForumMethods
    def has_forum_been_updated?
      return false unless is_gold?
      max_updated_at = ForumTopic.permitted.active.maximum(:updated_at)
      return false if max_updated_at.nil?
      return true if last_forum_read_at.nil?
      return max_updated_at > last_forum_read_at
    end
  end

  module LimitMethods
    def max_saved_searches
      if is_platinum?
        1_000
      else
        250
      end
    end

    def show_saved_searches?
      true
    end

    def can_upload?
      true
    end

    def upload_limited_reason
      nil
    end

    def can_comment?
      true
    end

    def is_comment_limited?
      false
    end

    def can_comment_vote?
      true
    end

    def can_remove_from_pools?
      true
    end

    def can_view_flagger?(flagger_id)
      true
    end

    def tag_query_limit
      if is_platinum?
        Danbooru.config.base_tag_query_limit * 2
      elsif is_gold?
        Danbooru.config.base_tag_query_limit
      else
        2
      end
    end

    def favorite_limit
      if is_platinum?
        nil
      elsif is_gold?
        20_000
      else
        10_000
      end
    end

    def api_regen_multiplier
      # regen this amount per second
      if is_platinum?
        4
      elsif is_gold?
        2
      else
        1
      end
    end

    def api_burst_limit
      # can make this many api calls at once before being bound by
      # api_regen_multiplier refilling your pool
      if is_platinum?
        60
      elsif is_gold?
        30
      else
        10
      end
    end

    def remaining_api_limit
      token_bucket.try(:token_count) || api_burst_limit
    end

    def statement_timeout
      if is_platinum?
        9_000
      elsif is_gold?
        6_000
      else
        3_000
      end
    end
  end

  module ApiMethods
    # blacklist all attributes by default. whitelist only safe attributes.
    def hidden_attributes
      super + attributes.keys.map(&:to_sym)
    end

    def method_attributes
      list = super + [
        :id, :created_at, :name, :level,
        :post_upload_count, :post_update_count, :note_update_count,
        :is_banned, :level_string,
      ]

      if id == CurrentUser.user.id
        list += BOOLEAN_ATTRIBUTES + [
          :updated_at, :email, :last_logged_in_at, :last_forum_read_at,
          :recent_tags, :comment_threshold, :default_image_size,
          :blacklisted_tags, :time_zone, :per_page,
          :custom_style, :favorite_count,
          :api_regen_multiplier, :api_burst_limit, :remaining_api_limit,
          :statement_timeout, :favorite_limit,
          :tag_query_limit, :max_saved_searches,
        ]
      end

      list
    end

    # extra attributes returned for /users/:id.json but not for /users.json.
    def full_attributes
      [
        :wiki_page_version_count, :pool_version_count,
        :forum_post_count, :comment_count, :upload_limit,
        :max_upload_limit
      ]
    end

    def to_legacy_json
      return {
        "name" => name,
        "id" => id,
        "level" => level,
        "created_at" => created_at.strftime("%Y-%m-%d %H:%M")
      }.to_json
    end
  end

  module CountMethods
    def wiki_page_version_count
      WikiPageVersion.for_user(id).count
    end

    def pool_version_count
      return nil unless PoolArchive.enabled?
      PoolArchive.for_user(id).count
    end

    def forum_post_count
      ForumPost.for_user(id).count
    end

    def comment_count
      Comment.for_creator(id).count
    end
  end

  module SearchMethods
    def named(name)
      where("lower(name) = ?", name)
    end

    def name_matches(name)
      where("lower(name) like ? escape E'\\\\'", name.to_escaped_for_sql_like)
    end

    def admins
      where("level = ?", Levels::ADMIN)
    end

    # UserDeletion#rename renames deleted users to `user_<1234>~`. Tildes
    # are appended if the username is taken.
    def deleted
      where("name ~ 'user_[0-9]+~*'")
    end

    def undeleted
      where("name !~ 'user_[0-9]+~*'")
    end

    def with_email(email)
      if email.blank?
        where("FALSE")
      else
        where("email = ?", email)
      end
    end

    def find_for_password_reset(name, email)
      if email.blank?
        where("FALSE")
      else
        where(["name = ? AND email = ?", name, email])
      end
    end

    def search(params)
      q = where("true")
      return q if params.blank?

      if params[:name].present?
        q = q.name_matches(params[:name].mb_chars.downcase.strip.tr(" ", "_"))
      end

      if params[:name_matches].present?
        q = q.name_matches(params[:name_matches].mb_chars.downcase.strip.tr(" ", "_"))
      end

      if params[:min_level].present?
        q = q.where("level >= ?", params[:min_level].to_i)
      end

      if params[:max_level].present?
        q = q.where("level <= ?", params[:max_level].to_i)
      end

      if params[:level].present?
        q = q.where("level = ?", params[:level].to_i)
      end

      if params[:id].present?
        q = q.where("id in (?)", params[:id].split(",").map(&:to_i))
      end

      bitprefs_length = BOOLEAN_ATTRIBUTES.length
      bitprefs_include = nil
      bitprefs_exclude = nil

      if bitprefs_include
        bitprefs_include.reverse!
        q = q.where("bit_prefs::bit(:len) & :bits::bit(:len) = :bits::bit(:len)",
                    {:len => bitprefs_length, :bits => bitprefs_include})
      end

      if bitprefs_exclude
        bitprefs_exclude.reverse!
        q = q.where("bit_prefs::bit(:len) & :bits::bit(:len) = 0::bit(:len)",
                    {:len => bitprefs_length, :bits => bitprefs_exclude})
      end

      if params[:current_user_first] == "true" && !CurrentUser.is_anonymous?
        q = q.order("id = #{CurrentUser.user.id.to_i} desc")
      end
      
      case params[:order]
      when "name"
        q = q.order("name")

      when "post_upload_count"
        q = q.order("post_upload_count desc")

      when "note_count"
        q = q.order("note_update_count desc")

      when "post_update_count"
        q = q.order("post_update_count desc")

      else
        q = q.order("created_at desc")
      end

      q
    end
  end

  module StatisticsMethods
    def deletion_confidence(days = 30)
      Reports::UserPromotions.deletion_confidence_interval_for(self, days)
    end
  end

  module SockPuppetMethods
    def notify_sock_puppets
      sock_puppet_suspects.each do |user|
      end
    end

    def sock_puppet_suspects
      if last_ip_addr.present?
        User.where(:last_ip_addr => last_ip_addr)
      end
    end
  end

  include BanMethods
  include NameMethods
  include PasswordMethods
  include AuthenticationMethods
  include FavoriteMethods
  include LevelMethods
  include EmailMethods
  include BlacklistMethods
  include ForumMethods
  include LimitMethods
  include ApiMethods
  include CountMethods
  extend SearchMethods
  include StatisticsMethods

  def initialize_default_image_size
    self.default_image_size = "large"
  end

  def can_update?(object, foreign_key = :user_id)
    is_moderator? || is_admin? || object.__send__(foreign_key) == id
  end

  def dmail_count
    if has_mail?
      "(#{dmails.unread.count})"
    else
      ""
    end
  end

  def hide_favorites?
    !CurrentUser.is_admin? && CurrentUser.user.id != id
  end

  def initialize_default_boolean_attributes
    self.enable_auto_complete = true
  end
end
