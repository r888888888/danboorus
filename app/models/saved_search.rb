class SavedSearch < ApplicationRecord
  module ListbooruMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def enabled?
        Danbooru.config.aws_sqs_saved_search_url.present?
      end

      def posts_search_available?
        enabled? && CurrentUser.is_gold?
      end

      def sqs_service
        SqsService.new(Danbooru.config.aws_sqs_saved_search_url)
      end

      def post_ids(user_id)
        return [] unless enabled?

        Cache.get(cache_key(user_id), 60) do
          queries = SavedSearch.queries_for(user_id)
          return [] if queries.empty?

          json = {
            "key" => Danbooru.config.listbooru_auth_key,
            "queries" => queries
          }.to_json

          uri = "#{Danbooru.config.listbooru_server}/v2/search"

          resp = HTTParty.post(uri, Danbooru.config.httparty_options.merge(body: json))
          if resp.success?
            resp.body.to_s.scan(/\d+/).map(&:to_i)
          else
            raise "HTTP error code: #{resp.code} #{resp.message}"
          end
        end
      end
    end
  end

  include ListbooruMethods

  belongs_to :user
  validates :query, :presence => true
  validate :validate_count
  attr_accessible :query
  before_create :update_user_on_create
  after_destroy :update_user_on_destroy
  after_save {|rec| Cache.delete(SavedSearch.cache_key(rec.user_id))}
  after_destroy {|rec| Cache.delete(SavedSearch.cache_key(rec.user_id))}
  before_validation :normalize

  def self.queries_for(user_id, options = {})
    SavedSearch.where(user_id: user_id).map(&:normalized_query).sort.uniq
  end

  def self.cache_key(user_id)
    "ss:#{user_id}"
  end

  def normalized_query
    Tag.normalize_query(query, sort: true)
  end

  def normalize
    self.query = Tag.normalize_query(query, sort: false)
  end

  def validate_count
    if user.saved_searches.count + 1 > user.max_saved_searches
      self.errors[:user] << "can only have up to #{user.max_saved_searches} " + "saved search".pluralize(user.max_saved_searches)
    end
  end

  def update_user_on_create
    if !user.has_saved_searches?
      user.update_attribute(:has_saved_searches, true)
    end
  end

  def update_user_on_destroy
    if user.saved_searches.count == 0
      user.update_attribute(:has_saved_searches, false)
    end
  end
end
