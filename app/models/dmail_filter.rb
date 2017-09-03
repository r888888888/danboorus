class DmailFilter < ApplicationRecord
  belongs_to :user
  # attr_accessible :words, :as => [:moderator, :gold, :platinum, :basic, :anonymous, :default, :admin]
  validates_presence_of :user
  before_validation :initialize_user

  def initialize_user
    unless user_id
      self.user_id = CurrentUser.user.id
    end
  end

  def filtered?(dmail)
    !dmail.from.is_moderator? && has_filter? && (dmail.body =~ regexp || dmail.title =~ regexp || dmail.from.name =~ regexp)
  end

  def has_filter?
    !words.strip.empty?
  end

  def regexp
    @regexp ||= Regexp.compile('\b(?:' + words.scan(/\S+/).map {|x| Regexp.escape(x)}.join("|") + ')\b')
  end
end
