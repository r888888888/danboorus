class Booru < ApplicationRecord
	PROTECTED_NAMES = %w(www)

	validates_length_of :name, maximum: 63
	validates_uniqueness_of :name
	validates_uniqueness_of :slug
	validates_exclusion_of :name, in: PROTECTED_NAMES
	validates_inclusion_of :status, in: %w(active deleted)
	belongs_to :creator, class_name: "User"
	before_validation :initialize_slug
	before_validation :initialize_creator
	before_validation :initialize_status
	has_many :bans
	has_many :comments
	has_many :comment_votes
	has_many :dmails
	has_many :dmail_filters
	has_many :forum_posts
	has_many :forum_subscriptions
	has_many :forum_topics
	has_many :forum_topic_visits
	has_many :ip_bans
	has_many :memberships
	has_many :users, through: :memberships
	has_many :mod_actions
	has_many :news_updates
	has_many :notes
	has_many :note_versions
	has_many :pixiv_ugoira_frame_data
	has_many :pools
	has_many :pool_archives
	has_many :posts
	has_many :post_votes
	has_many :saved_searches
	has_many :uploads
	has_many :wiki_pages
	has_many :wiki_page_versions

	def self.current
		Thread.current[:booru]
	end

	def self.current=(booru)
		Thread.current[:booru] = booru
	end

	def self.find_by_slug(slug)
		where(slug: slug).first
	end

	def initialize_status
		self.status ||= "active"
	end

	def initialize_creator
		self.creator_id = CurrentUser.id
	end

	def initialize_slug
		self.slug = name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "").gsub(/\A\d+/, "").gsub(/-{2,}/, "-")
	end
end
