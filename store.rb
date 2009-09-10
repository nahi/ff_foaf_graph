require 'tokyocabinet'

class Store
  attr_reader :force_update_for
  attr_reader :force_update_friends_for

  attr_reader :updated
  attr_reader :user_names
  attr_reader :group_names
  attr_reader :friends
  attr_reader :subscriptions
  attr_reader :subscribers
  attr_reader :groups

  def push(*ary)
    ary.each do |e|
      unless @all.key?(e)
        @queue << e
        @all[e] = true
      end
    end
  end

  def shift
    @queue.shift
  end

  def queue_size
    @queue.size
  end

  def all_size
    @all.size
  end

  def name_of(id)
    @user_names[id] || @group_names[id]
  end

  def initialize(dir)
    @force_update_for = {}
    @force_update_friends_for = {}
    @queue = []
    @all = {}
    @store_updated = File.join(dir, 'updated.tch')
    @store_user_names = File.join(dir, 'user_names.tch')
    @store_group_names = File.join(dir, 'group_names.tch')
    @store_friends = File.join(dir, 'friends.tch')
    @store_subscriptions = File.join(dir, 'subscriptions.tch')
    @store_subscribers = File.join(dir, 'subscribers.tch')
    @store_groups = File.join(dir, 'groups.tch')
    @updated = TokyoCabinet::BDB.new
    @user_names = TokyoCabinet::BDB.new
    @group_names = TokyoCabinet::BDB.new
    @friends = TokyoCabinet::BDB.new
    @subscriptions = TokyoCabinet::BDB.new
    @subscribers = TokyoCabinet::BDB.new
    @groups = TokyoCabinet::BDB.new
  end

  def open(param = nil, &block)
    param ||= TokyoCabinet::BDB::OCREAT | TokyoCabinet::BDB::OWRITER
    begin
      @updated.open(@store_updated, param)
      @user_names.open(@store_user_names, param)
      @group_names.open(@store_group_names, param)
      @friends.open(@store_friends, param)
      @subscriptions.open(@store_subscriptions, param)
      @subscribers.open(@store_subscribers, param)
      @groups.open(@store_groups, param)
      yield
    ensure
      close
    end
  end

private

  def close
    @updated.close
    @user_names.close
    @group_names.close
    @friends.close
    @subscriptions.close
    @subscribers.close
    @groups.close
  end
end
