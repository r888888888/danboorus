class AddHostToBoorus < ActiveRecord::Migration
  def change
  	add_column(:boorus, :host, :string, null: false, default: "localhost")
  end
end
