class DailyMaintenance
  def run
    ActiveRecord::Base.connection.execute("set statement_timeout = 0")
    Upload.delete_all(['created_at < ?', 1.day.ago])
    ModAction.delete_all(['created_at < ?', 30.days.ago])
    Delayed::Job.delete_all(['created_at < ?', 45.days.ago])
    PostVote.prune!
    CommentVote.prune!
    ForumSubscription.process_all!
    Tag.clean_up_negative_post_counts!
    TokenBucket.prune!
  end
end
