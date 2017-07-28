class UserPromotion
  attr_reader :user, :promoter, :new_level, :options

  def initialize(user, promoter, new_level, options = {})
    @user = user
    @promoter = promoter
    @new_level = new_level
    @options = options
  end

  def promote!
    validate
    user.level = new_level
    user.inviter_id = promoter.id
    create_user_feedback unless options[:skip_feedback]
    create_dmail unless options[:skip_dmail]
    user.save
  end

private
    
  def validate
    # admins can do anything
    return if promoter.is_admin?

    # can't promote/demote moderators
    raise User::PrivilegeError if user.is_moderator?

    # can't promote to admin      
    raise User::PrivilegeError if new_level.to_i >= User::Levels::ADMIN
  end

  def build_messages
    messages = []

    if user.level_changed?
      if user.level > user.level_was
        messages << "You have been promoted to a #{user.level_string} level account from #{user.level_string_was}."
      elsif user.level < user.level_was
        messages << "You have been demoted to a #{user.level_string} level account from #{user.level_string_was}."
      end
    end

    messages.join("\n")
  end

  def create_dmail
    Dmail.create_automated(
      :to_id => user.id,
      :title => "You have been promoted",
      :body => build_messages
    )
  end

  def create_user_feedback
    user.feedback.create(
      :body => build_messages,
      :disable_dmail_notification => true
    )
  end
end
