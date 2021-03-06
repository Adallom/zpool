actions :create, :destroy

attribute :name, kind_of: String
attribute :disks, kind_of: Array, default: []
attribute :entities, kind_of: Hash, default: {}


attribute :info, kind_of: Mixlib::ShellOut, default: nil
attribute :state, kind_of: String, default: nil

# Optional attributes
attribute :force, kind_of: [TrueClass, FalseClass], default: false
attribute :recursive, kind_of: [TrueClass, FalseClass], default: false
attribute :ashift, kind_of: Integer, default: 0
attribute :graceful, kind_of: [TrueClass, FalseClass], default: true

def initialize(*args)
  super
  @action = :create
end
