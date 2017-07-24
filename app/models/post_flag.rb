class PostFlag < ApplicationRecord
  class Error < Exception ; end

  COOLDOWN_PERIOD = 3.days

  belongs_to :creator, :class_name => "User"
  belongs_to :post
  validates_presence_of :reason, :creator_id, :creator_ip_addr
  validate :validate_post
  before_validation :initialize_creator, :on => :create
  validates_uniqueness_of :creator_id, :scope => :post_id, :on => :create, :unless => :is_deletion, :message => "have already flagged this post"
  before_save :update_post
  attr_accessible :post, :post_id, :reason, :is_resolved, :is_deletion
  attr_accessor :is_deletion

  scope :by_users, lambda { where.not(creator: User.system) }
  scope :by_system, lambda { where(creator: User.system) }
  scope :in_cooldown, lambda { by_users.where("created_at >= ?", COOLDOWN_PERIOD.ago) }

  module SearchMethods
    def reason_matches(query)
      if query =~ /\*/
        where("post_flags.reason ILIKE ? ESCAPE E'\\\\'", query.to_escaped_for_sql_like)
      else
        where("to_tsvector('english', post_flags.reason) @@ plainto_tsquery(?)", query.to_escaped_for_tsquery)
      end
    end

    def duplicate
      where("to_tsvector('english', post_flags.reason) @@ to_tsquery('dup | duplicate | sample | smaller')")
    end

    def not_duplicate
      where("to_tsvector('english', post_flags.reason) @@ to_tsquery('!dup & !duplicate & !sample & !smaller')")
    end

    def post_tags_match(query)
      PostQueryBuilder.new(query).build(self.joins(:post))
    end

    def resolved
      where("is_resolved = ?", true)
    end

    def unresolved
      where("is_resolved = ?", false)
    end

    def recent
      where("created_at >= ?", 1.day.ago)
    end

    def old
      where("created_at <= ?", 3.days.ago)
    end

    def for_creator(user_id)
      where("creator_id = ?", user_id)
    end

    def search(params)
      q = order("post_flags.id desc")
      return q if params.blank?

      if params[:reason_matches].present?
        q = q.reason_matches(params[:reason_matches])
      end

      if params[:creator_id].present? && CurrentUser.can_view_flagger?(params[:creator_id].to_i)
        q = q.where("creator_id = ?", params[:creator_id].to_i)
      end

      if params[:creator_name].present?
        flagger_id = User.name_to_id(params[:creator_name].strip)
        if flagger_id && CurrentUser.can_view_flagger?(flagger_id)
          q = q.where("creator_id = ?", flagger_id)
        else
          q = q.where("false")
        end
      end

      if params[:post_id].present?
        q = q.where(post_id: params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      if params[:is_resolved] == "true"
        q = q.resolved
      elsif params[:is_resolved] == "false"
        q = q.unresolved
      end

      q
    end
  end

  module ApiMethods
    def hidden_attributes
      list = super
      unless CurrentUser.is_moderator?
        list += [:creator_id]
      end
      super + list
    end
  end

  extend SearchMethods
  include ApiMethods

  def update_post
    post.update_column(:is_flagged, true) unless post.is_flagged?
  end

  def validate_post
    errors[:post] << "is locked and cannot be flagged" if post.is_status_locked?
    errors[:post] << "is deleted" if post.is_deleted?
  end

  def initialize_creator
    self.creator_id ||= CurrentUser.id
    self.creator_ip_addr = CurrentUser.ip_addr if creator_ip_addr == "127.0.0.1" || creator_ip_addr.blank?
  end

  def resolve!
    update_column(:is_resolved, true)
  end

  def flag_count_for_creator
    PostFlag.where(:creator_id => creator_id).recent.count
  end
end
