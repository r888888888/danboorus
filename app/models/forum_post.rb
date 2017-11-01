class ForumPost < ApplicationRecord
  include Mentionable

  attr_readonly :topic_id
  belongs_to_booru
  belongs_to_creator
  belongs_to_updater
  belongs_to :topic, :class_name => "ForumTopic"
  before_validation :initialize_is_deleted, :on => :create
  after_create :update_topic_updated_at_on_create
  after_update :update_topic_updated_at_on_update_for_original_posts
  after_destroy :update_topic_updated_at_on_destroy
  validates_presence_of :body, :creator_id
  validate :validate_topic_is_unlocked
  validate :topic_id_not_invalid
  validate :topic_is_not_restricted, :on => :create
  before_destroy :validate_topic_is_unlocked
  after_save :delete_topic_if_original_post
  after_update(:if => lambda {|rec| rec.updater_id != rec.creator_id}) do |rec|
    ModAction.log("#{CurrentUser.name} updated forum ##{rec.id}")
  end
  after_destroy(:if => lambda {|rec| rec.updater_id != rec.creator_id}) do |rec|
    ModAction.log("#{CurrentUser.name} deleted forum ##{rec.id}")
  end
  mentionable(
    :message_field => :body, 
    :title => lambda {|user_name| %{#{creator_name} mentioned you in topic ##{topic_id} (#{topic.title})}},
    :body => lambda {|user_name| %{@#{creator_name} mentioned you in topic ##{topic_id} ("#{topic.title}":[/forum_topics/#{topic_id}?page=#{forum_topic_page}]):\n\n[quote]\n#{DText.excerpt(body, "@"+user_name)}\n[/quote]\n}},
  )

  concerning :SearchMethods do
    module ClassMethods
      def body_matches(body)
        where("forum_posts.text_index @@ plainto_tsquery(E?)", body.to_escaped_for_tsquery)
      end

      def topic_title_matches(title)
        joins(:topic).where("forum_topics.text_index @@ plainto_tsquery(E?)", title.to_escaped_for_tsquery_split)
      end

      def for_user(user_id)
        where("forum_posts.creator_id = ?", user_id)
      end

      def creator_name(name)
        where("forum_posts.creator_id = ?", User.name_to_id(name))
      end

      def active
        where("forum_posts.is_deleted = false")
      end

      def permitted
        q = where(booru_id: Booru.current.id).joins(:topic)
        if !CurrentUser.is_moderator?
          q = q.where("forum_topics.mods_only = false")
        end
        q
      end

      def search(params)
        q = permitted
        return q if params.blank?

        if params[:creator_id].present?
          q = q.where("forum_posts.creator_id = ?", params[:creator_id].to_i)
        end

        if params[:topic_id].present?
          q = q.where("forum_posts.topic_id = ?", params[:topic_id].to_i)
        end

        if params[:topic_title_matches].present?
          q = q.topic_title_matches(params[:topic_title_matches])
        end

        if params[:body_matches].present?
          q = q.body_matches(params[:body_matches])
        end

        if params[:creator_name].present?
          q = q.creator_name(params[:creator_name].tr(" ", "_"))
        end

        if params[:topic_category_id].present?
          q = q.joins(:topic).where("forum_topics.category_id = ?", params[:topic_category_id].to_i)
        end

        q
      end
    end
  end

  concerning :ApiMethods do
    def as_json(options = {})
      if !CurrentUser.is_moderator? && topic.mods_only
        options[:only] = [:id]
      end

      super(options)
    end
    
    def hidden_attributes
      super + [:text_index]
    end
  end

  def self.new_reply(params)
    if params[:topic_id]
      new(:topic_id => params[:topic_id])
    elsif params[:post_id]
      forum_post = ForumPost.find(params[:post_id])
      forum_post.build_response
    else
      new
    end
  end

  def validate_topic_is_unlocked
    return if CurrentUser.is_moderator?
    return if topic.nil?

    if topic.is_locked?
      errors.add(:topic, "is locked")
      return false
    else
      return true
    end
  end

  def topic_id_not_invalid
    if topic_id && !topic
      errors.add(:base, "Topic ID is invalid")
    end
  end

  def topic_is_not_restricted
    if topic && !topic.visible?(creator)
      errors.add(:topic, "restricted")
    end
  end

  def editable_by?(user)
    (creator_id == user.id || user.is_moderator?) && visible?(user)
  end

  def visible?(user)
    user.is_moderator? || (topic.visible?(user) && !is_deleted?)
  end

  def update_topic_updated_at_on_create
    if topic
      # need to do this to bypass the topic's original post from getting touched
      ForumTopic.where(:id => topic.id).update_all(["updater_id = ?, response_count = response_count + 1, updated_at = ?", CurrentUser.id, Time.now])
      topic.response_count += 1
    end
  end

  def update_topic_updated_at_on_update_for_original_posts
    if is_original_post?
      topic.touch
    end
  end

  def delete!
    update(is_deleted: true)
    update_topic_updated_at_on_delete
  end

  def undelete!
    update(is_deleted: false)
    update_topic_updated_at_on_undelete
  end

  def update_topic_updated_at_on_delete
    max = ForumPost.where(:topic_id => topic.id, :is_deleted => false).order("updated_at desc").first
    if max
      ForumTopic.where(:id => topic.id).update_all(["updated_at = ?, updater_id = ?", max.updated_at, max.updater_id])
    end
  end

  def update_topic_updated_at_on_undelete
    if topic
      ForumTopic.where(:id => topic.id).update_all(["updater_id = ?, updated_at = ?", CurrentUser.id, Time.now])
    end
  end

  def update_topic_updated_at_on_destroy
    max = ForumPost.where(:topic_id => topic.id, :is_deleted => false).order("updated_at desc").first
    if max
      ForumTopic.where(:id => topic.id).update_all(["response_count = response_count - 1, updated_at = ?, updater_id = ?", max.updated_at, max.updater_id])
      topic.response_count -= 1
    else
      ForumTopic.where(:id => topic.id).update_all("response_count = response_count - 1")
      topic.response_count -= 1
    end
  end

  def initialize_is_deleted
    self.is_deleted = false if is_deleted.nil?
  end

  def quoted_response
    DText.quote(body, creator_name)
  end

  def forum_topic_page
    ((ForumPost.where("topic_id = ? and created_at <= ?", topic_id, created_at).count) / Danbooru.config.posts_per_page.to_f).ceil
  end

  def is_original_post?
    ForumPost.exists?(["id = ? and id = (select _.id from forum_posts _ where _.topic_id = ? order by _.id asc limit 1)", id, topic_id])
  end

  def delete_topic_if_original_post
    if is_deleted? && is_original_post?
      topic.update(is_deleted: true)
    end

    true
  end

  def build_response
    dup.tap do |x|
      x.body = x.quoted_response
    end
  end
end
