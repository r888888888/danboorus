class UserPresenter
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def name
    user.pretty_name
  end

  def join_date
    user.created_at.strftime("%Y-%m-%d")
  end

  def level
    user.level_string
  end

  def ban_reason
    if user.is_banned?
      "#{user.recent_ban.reason}; expires #{user.recent_ban.expires_at} (#{user.bans.count} bans total)"
    else
      nil
    end
  end

  def permissions
    ""
  end

  def posts_for_saved_search
    if !SavedSearch.enabled?
      return Post.where("false")
    end

    ids = SavedSearch.post_ids(CurrentUser.user.id)

    if ids.any?
      Post.where("id in (?)", ids.map(&:to_i)).order("id desc").limit(10)
    else
      Post.where("false")
    end
  end

  def upload_limit
    nil
  end

  def uploads
    @uploads ||= Post.where("uploader_id = ?", user.id).order("id desc").limit(6)
  end

  def has_uploads?
    user.post_upload_count > 0
  end

  def favorites
    @favorites ||= begin
      user.favorites.limit(6).joins(:post).reorder("favorites.id desc").map(&:post).compact
    end
  end

  def has_favorites?
    user.favorite_count > 0
  end

  def upload_count(template)
    if Booru.current
      template.link_to(user.post_upload_count, template.booru_posts_path(Booru.current.slug, :tags => "user:#{user.name}"))
    else
      user.post_upload_count
    end
  end

  def deleted_upload_count(template)
    if Booru.current
      template.link_to(Post.for_user(user.id).deleted.count, template.booru_posts_path(Booru.current.slug, :tags => "status:deleted user:#{user.name}"))
    else
      Post.for_user(user.id).deleted.count
    end
  end

  def favorite_count(template)
    template.link_to(user.favorite_count, template.favorites_path(:user_id => user.id))
  end

  def comment_count(template)
    if Booru.current
      template.link_to(user.comment_count, template.booru_comments_path(Booru.current.slug, :search => {:creator_id => user.id}, :group_by => "comment"))
    else
      user.comment_count
    end
  end

  def commented_posts_count(template)
    count = Post.fast_count("commenter:#{user.name}")
    if Booru.current
      template.link_to(count, template.booru_posts_path(Booru.current.slug, :tags => "commenter:#{user.name} order:comment"))
    else
      count
    end
  end

  def post_version_count(template)
    if Booru.current
      template.link_to(user.post_update_count, template.booru_post_versions_path(Booru.current.slug, :lr => user.id, :search => {:updater_id => user.id}))
    else
      user.post_update_count
    end
  end

  def note_version_count(template)
    if Booru.current
      template.link_to(user.note_update_count, template.booru_note_versions_path(Booru.current.slug, :search => {:updater_id => user.id}))
    else
      user.note_update_count
    end
  end

  def noted_posts_count(template)
    count = Post.fast_count("noteupdater:#{user.name}")
    if Booru.current
      template.link_to(count, template.booru_posts_path(Booru.current.slug, :tags => "noteupdater:#{user.name} order:note"))
    else
      count
    end
  end

  def wiki_page_version_count(template)
    if Booru.current
      template.link_to(user.wiki_page_version_count, template.booru_wiki_page_versions_path(Booru.current.slug, :search => {:updater_id => user.id}))
    else
      user.wiki_page_version_count
    end
  end

  def forum_post_count(template)
    if Booru.current
      template.link_to(user.forum_post_count, template.booru_forum_posts_path(Booru.current.slug, :search => {:creator_id => user.id}))
    else
      user.forum_post_count
    end
  end

  def pool_version_count(template)
    if PoolArchive.enabled?
      if Booru.current
        template.link_to(user.pool_version_count, template.pool_versions_path(:search => {:updater_id => user.id}))
      else
        user.pool_version_count
      end
    else
      "N/A"
    end
  end

  def feedbacks(template)
    count = user.feedback.count

    template.link_to("#{count}", template.user_feedbacks_path(:search => {:user_id => user.id}))
  end
  
  def previous_names(template)
    user.user_name_change_requests.map { |req| template.link_to req.original_name, req }.join(", ").html_safe
  end
end
