class SwitchToSha2Hash < ActiveRecord::Migration
  def change
  	rename_column(:posts, :md5, :sha256)
  	rename_index(:posts, "index_posts_on_md5", "index_posts_on_sha256")
  	rename_column(:uploads, :md5_confirmation, :sha256_confirmation)
  end
end
