require 'ff'
require 'store'
require 'graphviz'

id = ARGV.shift or raise

class Graph
  def initialize(viz, limit = 200)
    @id_counter = 0
    @id_map = {}
    @viz = viz
    @limit = limit
    @nodes = {}
    @edges = {}
  end

  def node(id, name, opt = {})
    return unless id and name
    if mapped = map_id(id)
      add_node(id, name, mapped, opt.merge(:URL => 'http://friendfeed.com/' + id))
    end
  end

  def force_node(id, name, opt = {})
    return unless id and name
    mapped = map_id(id, true)
    add_node(name, name, mapped, opt)
  end

  def [](id)
    if mapped = map_id(id)
      @nodes[mapped]
    end
  end

  def edge(id1, id2, opt = {})
    return unless self[id1] and self[id2]
    key = [id1, id2].sort
    default = {
      :arrowhead => 'lnormal',
      :len => '0.05',
      :tooltip => "#{id1} - #{id2}"
    }
    @edges[key] ||= @viz.add_edge(self[id1], self[id2], default.merge(opt))
  end

  def output(*arg)
    @viz.output(*arg)
  end

private

  def add_node(id, name, mapped, opt)
    default = {
      :label => id,
      :tooltip => name,
      :shape => 'ellipse',
      :style => 'filled',
      :fillcolor => 'white',
      :margin => '0.01',
      :labelfontsize => '14',
      :fontsize => '11'
    }
    @nodes[mapped] ||= @viz.add_node('n_' + mapped, default.merge(opt))
  end

  def map_id(id, force = false)
    @id_map[id] ||= new_id(force)
  end

  def new_id(force = false)
    @id_counter += 1
    if force or @limit >= @id_counter
      "n_#{@id_counter}"
    end
  end
end

store = Store.new('db')
opt = {
  :type => 'digraph',
  :use => 'twopi',
  :center => 'true',
  :pack => 'true',
  :packmode => 'node',
  :sep => '1.6',
  :overlap => 'false',
  :outputorder => 'edgesfirst',
  :output => 'svg',
}
viz = GraphViz.new(id, opt)
graph = Graph.new(viz)

include_group = false

store.open(TokyoCabinet::BDB::OREADER) do
  graph.node(id, store.name_of(id), :root => 'true', :color => 'yellow', :fillcolor => 'red', :fontcolor => 'yellow')
  friends = (store.friends[id] || '').split(',')
  subscriptions = (store.subscriptions[id] || '').split(',')
  subscribers = (store.subscribers[id] || '').split(',')
  groups = (store.groups[id] || '').split(',')
  # add all friends
  c = 0
  friends.each do |e|
    unless graph.node(e, store.name_of(e), :color => 'red', :fontcolor => 'red')
      c += 1
    end
    graph.edge(id, e, :color => 'red', :arrowhead => 'none')
  end
  if c > 0
    graph.force_node('ofriends', "other(#{c})", :color => 'red')
    graph.edge(id, 'ofriends', :color => 'red', :arrowhead => 'none')
  end
  if include_group
    # add group only if the group is shared with friends
    c = 0
    groups.each do |e|
      members = (store.subscribers[e] || '').split(',')
      if members.any? { |f| friends.include?(f) }
        unless graph.node(e, store.name_of(e), :color => 'blue', :fontcolor => 'blue', :shape => 'box')
          c += 1
        end
        graph.edge(id, e, :color => 'blue')
      end
    end
    if c > 0
      graph.force_node('ogroups', "other(#{c})", :color => 'blue', :shape => 'box')
      graph.edge(id, 'ogroups', :color => 'blue')
    end
  end
  # add fof only if the fof is in subscriptions or subscribers
  friends.each do |e|
    c = 0
    fof = (store.friends[e] || '').split(',')
    fof.each do |f|
      if friends.include?(f) or subscriptions.include?(f) or subscribers.include?(f)
        unless graph.node(f, store.name_of(f), :color => 'orange', :fontcolor => 'orange')
          c += 1
        end
        if friends.include?(f)
          graph.edge(e, f, :color => 'red', :arrowhead => 'none')
        else
          graph.edge(e, f, :color => 'orange', :arrowhead => 'none')
        end
      end
    end
    if c > 0
      graph.force_node('ofof_' + e, "other(#{c})", :color => 'orange')
      graph.edge(e, 'ofof_' + e, :color => 'orange')
    end
  end
  # add links for subscriptions
  subscriptions.each do |e|
    #graph.node(e, store.name_of(e), :color => 'green')
    graph.edge(id, e, :color => 'green')
  end
  # add links for subscriptions of friends
  friends.each do |e|
    sof = (store.subscriptions[e] || '').split(',')
    sof.each do |f|
      #graph.node(f, store.name_of(f), :color => 'lightgreen')
      graph.edge(e, f, :color => 'lightgreen')
    end
  end
  # no links for subscribers; it pulls fof
=begin
  subscribers.each do |e|
    #graph.node(e, store.name_of(e), :color => 'yellow')
    graph.edge(e, id, :color => 'yellow')
  end
=end
  # add links for group members
  if include_group
    groups.each do |e|
      members = (store.subscribers[e] || '').split(',')
      members.each do |f|
        #graph.node(f, store.name_of(f), :color => 'lightblue')
        graph.edge(f, e, :color => 'lightblue')
      end
    end
  end
end

graph.output(:file => "#{id}.svg")
