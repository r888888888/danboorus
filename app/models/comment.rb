class Comment < ApplicationRecord
  include Mentionable

  before_validation(on: :create) do |rec|
    rec.ip_addr = CurrentUser.ip_addr
  end
  validate :validate_post_exists, :on => :create
  validates_format_of :body, :with => /\S/, :message => 'has no content'
  belongs_to_booru
  belongs_to :post
  belongs_to_creator
  belongs_to_updater
  has_many :votes, :class_name => "CommentVote", :dependent => :destroy
  after_create :update_last_commented_at_on_create
  after_update do |rec|
    if rec.creator_id != CurrentUser.id
      ModAction.log("comment ##{rec.id} updated by #{CurrentUser.name}")
    end
  end
  after_save :update_last_commented_at_on_destroy, :if => lambda {|rec| rec.is_deleted? && rec.is_deleted_changed?}
  after_save do |rec|
    if rec.is_deleted? && rec.is_deleted_changed? && CurrentUser.id != rec.creator_id
      ModAction.log("comment ##{rec.id} deleted by #{CurrentUser.name}")
    end
  end
  #attr_accessible :body, :post_id, :is_deleted, :as => [:basic, :gold, :platinum, :moderator, :admin]
  #attr_accessible :is_sticky, :as => [:moderator, :admin]
  mentionable(
    :message_field => :body, 
    :title => lambda {|user_name| "#{creator_name} mentioned you in a comment on post ##{post_id}"},
    :body => lambda {|user_name| "@#{creator_name} mentioned you in a \"comment\":/posts/#{post_id}#comment-#{id} on post ##{post_id}:\n\n[quote]\n#{DText.excerpt(body, "@"+user_name)}\n[/quote]\n"},
  )

  module SearchMethods
    def recent
      reorder("comments.id desc").limit(6)
    end

    def body_matches(query)
      where("body_index @@ plainto_tsquery(?)", query.to_escaped_for_tsquery_split).order("comments.id DESC")
    end

    def hidden(user)
      where("score < ? and is_sticky = false", user.comment_threshold)
    end

    def visible(user)
      where("score >= ? or is_sticky = true", user.comment_threshold)
    end

    def deleted
      where("comments.is_deleted = true")
    end

    def undeleted
      where("comments.is_deleted = false")
    end

    def sticky
      where("comments.is_sticky = true")
    end

    def unsticky
      where("comments.is_sticky = false")
    end

    def post_tags_match(query)
      PostQueryBuilder.new(query).build(self.joins(:post)).reorder("")
    end

    def for_creator(user_id)
      user_id.present? ? where("creator_id = ?", user_id) : where("false")
    end

    def for_creator_name(user_name)
      for_creator(User.name_to_id(user_name))
    end

    def search(params)
      q = where("true")

      if params[:body_matches].present?
        q = q.body_matches(params[:body_matches])
      end

      if params[:id].present?
        q = q.where("id in (?)", params[:id].split(",").map(&:to_i))
      end

      if params[:post_id].present?
        q = q.where("post_id in (?)", params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      if params[:creator_name].present?
        q = q.for_creator_name(params[:creator_name])
      end

      if params[:creator_id].present?
        q = q.for_creator(params[:creator_id].to_i)
      end

      q = q.deleted if params[:is_deleted] == "true"
      q = q.undeleted if params[:is_deleted] == "false"

      q = q.sticky if params[:is_sticky] == "true"
      q = q.unsticky if params[:is_sticky] == "false"

      case params[:order]
      when "post_id", "post_id_desc"
        q = q.order("comments.post_id DESC, comments.id DESC")
      when "score", "score_desc"
        q = q.order("comments.score DESC, comments.id DESC")
      when "updated_at", "updated_at_desc"
        q = q.order("comments.updated_at DESC")
      else
        q = q.order("comments.id DESC")
      end

      q
    end
  end

  module VoteMethods
    def vote!(val)
      numerical_score = val == "up" ? 1 : -1
      vote = votes.create!(:score => numerical_score)

      if vote.is_positive?
        update_column(:score, score + 1)
      elsif vote.is_negative?
        update_column(:score, score - 1)
      end

      return vote
    end

    def unvote!
      vote = votes.where("creator_id = ?", CurrentUser.user.id).first

      if vote
        if vote.is_positive?
          update_column(:score, score - 1)
        else
          update_column(:score, score + 1)
        end

        vote.destroy
      else
        raise CommentVote::Error.new("You have not voted for this comment")
      end
    end
  end

  extend SearchMethods
  include VoteMethods

  def validate_post_exists
    errors.add(:post, "must exist") unless Post.exists?(post_id)
  end

  def update_last_commented_at_on_create
    Post.where(:id => post_id).update_all(:last_commented_at => created_at)
  end

  def update_last_commented_at_on_destroy
    other_comments = Comment.where("post_id = ? and id <> ?", post_id, id).order("id DESC")
    if other_comments.count == 0
      Post.where(:id => post_id).update_all(:last_commented_at => nil)
    else
      Post.where(:id => post_id).update_all(:last_commented_at => other_comments.first.created_at)
    end

    true
  end

  def editable_by?(user)
    creator_id == user.id || user.is_moderator?
  end

  def hidden_attributes
    super + [:body_index]
  end

  def method_attributes
    super + [:creator_name, :updater_name]
  end

  def delete!
    update({ :is_deleted => true }, :as => CurrentUser.role)
  end

  def undelete!
    update({ :is_deleted => false }, :as => CurrentUser.role)
  end

  def quoted_response
    DText.quote(body, creator_name)
  end
end
