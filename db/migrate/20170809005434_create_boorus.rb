class CreateBoorus < ActiveRecord::Migration
  def change
    create_table :boorus do |t|
    	t.string :name, null: false
      t.string :slug, null: false
    	t.string :desc, null: false, default: ""
    	t.integer :creator_id, null: false
    	t.string :host, null: false
      t.timestamps null: false
      t.string :status, null: false
    end

    add_index :boorus, :slug
  end
end
