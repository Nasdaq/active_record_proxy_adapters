# frozen_string_literal: true

class DummyMigration2 < ActiveRecord::Migration::Current
  def up
    puts "#{self.class.name} up"
  end

  def down
    puts "#{self.class.name} down"
  end
end
