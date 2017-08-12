class Booru < ApplicationRecord
	validates_length_of :name, maximum: 255
	validates_inclusion_of :status, in: %w(active deleted migrating migrated)
	belongs_to :creator, class_name: "User"
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
		where(slug: slug.downcase).first
	end
end
