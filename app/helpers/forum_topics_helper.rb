module ForumTopicsHelper
  def forum_topic_category_select(object, field)
    select(object, field, ForumTopic.reverse_category_mapping.to_a)
  end

  def available_min_user_levels
  	if CurrentUser.is_moderator?
  		[["Mod Only", "true"], ["All", "false"]]
  	else
  		[["All", "false"]]
  	end
  end
end
