require 'time'
require 'ff'
require 'tokyocabinet'
require 'store'

id = ARGV.shift or raise
mode = ARGV.shift

def trace(client, store, opt = {})
  id = store.shift
  return unless id
  unless store.force_update_for[id]
    if (skip_after = opt[:skip_after]) and (updated = store.updated[id])
      if Time.now - Time.parse(updated) < skip_after
        p "skip #{id}: last updated at #{store.updated[id]}"
        return
      end
    end
  end
  fi = client.feedinfo(id, :include => 'name,type,subscriptions,subscribers')
  return unless fi # may be private
  type = fi['type']
  name = fi['name']
  name_map = {}
  sub_map = {}
  friends = []
  subscriptions = []
  groups = []
  subscribers = []
  if fi['subscriptions']
    fi['subscriptions'].each do |sub|
      sub_id = sub['id']
      name_map[sub_id] = sub['name']
      case sub['type']
      when 'user'
        subscriptions << sub_id
        sub_map[sub_id] = true
      when 'group'
        groups << sub_id
      end
    end
  end
  if fi['subscribers']
    fi['subscribers'].each do |sub|
      sub_id = sub['id']
      name_map[sub_id] = sub['name']
      if sub['type'] == 'user'
        if sub_map.key?(sub_id)
          friends << sub_id
        else
          subscribers << sub_id
        end
      end
    end
  end
  subscriptions -= friends
  p "#{type} - #{id} (#{name}): #{friends.size} friends, #{subscriptions.size} subscriptions, #{subscribers.size} subscribers, #{groups.size} groups"
  # record to the store
  case type
  when 'user'
    store.user_names[id] = name
  when 'group'
    store.group_names[id] = name
  else
    return
  end
  # record friends, subscriptions, subscribers and groups.
  store.friends[id] = friends.join(',')
  store.subscriptions[id] = subscriptions.join(',')
  store.subscribers[id] = subscribers.join(',')
  store.groups[id] = groups.join(',')
  store.updated[id] = Time.now.xmlschema
  # record names of subscriptions and subscribers
  friends.each do |e|
    store.user_names[e] = name_map[e]
  end
  subscriptions.each do |e|
    store.user_names[e] = name_map[e]
  end
  subscribers.each do |e|
    store.user_names[e] = name_map[e]
  end
  groups.each do |e|
    store.group_names[e] = name_map[e]
  end
  # fof
  if store.force_update_friends_for[id]
    store.push(*friends)
    friends.each do |e|
      store.force_update_for[e] = true
    end
  end
  if opt[:mode] == 'crawl'
    store.push(*friends)
    store.push(*subscriptions)
    #store.push(*subscribers)
  end
  # should fetch group subscribers (members)
  store.push(*groups)
end

client = FriendFeed::APIV2Client.new
# We use non SSL connection for fetching public profiles.
client.url_base = 'http://friendfeed-api.com/v2/'

store = Store.new('db')
store.open do
  store.push(id)
  store.force_update_for[id] = true
  if mode != 'crawl'
    store.force_update_friends_for[id] = true
  end
  while store.queue_size > 0
    puts "store size: #{store.queue_size}/#{store.all_size}"
    trace(client, store, :skip_after => 3 * 24 * 3600, :mode => mode) {}
  end
end
