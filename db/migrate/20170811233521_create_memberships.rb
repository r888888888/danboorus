class CreateMemberships < ActiveRecord::Migration
  def change
    create_table :memberships do |t|
    	t.integer :booru_id, null: false
    	t.integer :user_id, null: false
    	t.boolean :is_admin, null: false, default: false
    	t.boolean :is_moderator, null: false, default: false
      t.timestamps null: false
    end

    add_index :memberships, :booru_id
    add_index :memberships, :user_id
  end
end
