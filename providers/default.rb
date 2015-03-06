include Chef::Mixin::ShellOut

def load_current_resource
  @zpool = Chef::Resource::Zpool.new(new_resource.name)
  # Chef::Log.info("Zpool - @zpool has been set to: " + @zpool.to_s) 
  @zpool.name(new_resource.name)
  @zpool.disks(new_resource.disks)
  @zpool.entities(new_resource.entities)
  @zpool.graceful(new_resource.graceful)
  @zpool.info(info)
  @zpool.state(state)
end


#create vdevs from a flat disk declaration
action :create do
# Chef::Log.info("Zpool - Working on zpool entities for #{@zpool.name}. DISKS is: #{@zpool.disks} Entities RAW are: " + @zpool.entities.to_s)
sanity?
Chef::Log.info("Zpool - Sanity OK, no conceptual duplicate assignments found")
  unless @zpool.disks.empty? or !@zpool.disks.select { |a| a == "cache" or a == "log" or a == "mirror" or a =~ /^[raid]/ }.empty?
    skipped_disks = []
    if created?
      if online?
        extract_short_name(@zpool.disks).each do |disk|
          if vdevs.include? disk
          	Chef::Log.info("Zpool - Disk #{disk} is already in pool #{@zpool.name}, so skipping any actions on it")	
            skipped_disks << disk
          	next 
          end
        end
        disks_to_add = extract_short_name(@zpool.disks).select { |e| !skipped_disks.include?(e) }
        disks_to_add = extract_short_name(disks_to_add)
        Chef::Log.info("Zpool - Adding #{disks_to_add} to pool #{@zpool.name}")
        shell_out!("zpool add #{args_from_resource(new_resource)} #{@zpool.name} #{disks_to_add.join(' ')}") unless disks_to_add.empty?
        new_resource.updated_by_last_action(true)
      else
        Chef::Log.warn("Zpool #{@zpool.name} is #{@zpool.state}")
      end
    else
      Chef::Log.info("Zpool - Creating zpool #{@zpool.name}")
      shell_out!("zpool create #{args_from_resource(new_resource)} #{@zpool.name} #{@zpool.disks.join(' ')}")
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info("Zpool - @zpool.disks of: #{@zpool.disks}, is either empty or contains \"tree\" directives")
  end


  #create vdevs from a entities hierarchy
  unless @zpool.entities.empty?
    Chef::Log.info("Zpool - Working on zpool entities for #{@zpool.name}. Entities RAW are: " + @zpool.entities.to_s)
    @zpool.entities.each do |type,disks|
      @extract_path = []
      @extract_disks = []
      Chef::Log.info("Zpool - Working on zpool #{@zpool.name}, entity type of: \"" + type.to_s + "\" disks of: #{disks}")
      if disks.kind_of?(Hash)
        Chef::Log.info("Zpool - Found \"type\" of \"#{type}\" to be a Hash.")
        @extract_path = handle_layer(disks, type, "path")
        Chef::Log.info("Zpool - extract_path is #{@extract_path}")
        @extract_disks = handle_layer(disks, type, "disks")
        Chef::Log.info("Zpool - extract_disks is #{@extract_disks}")
      end
     
      if @extract_disks.empty?
       @extract_disks << extract_short_name(disks)
      end
      if @extract_path.empty?
       @extract_path << type
      end

      Chef::Log.info("Zpool - using @extract_disks of: " + @extract_disks.flatten.to_s) 
      unless (all_vdevs & @extract_disks.flatten).size > 0 #AND type (somehow)
        Chef::Log.info("Zpool - @extract_disks of: " + @extract_disks.flatten.to_s + " are NOT in any pool, as seen by all_vdevs of: " + all_vdevs.to_s)
      else
        Chef::Log.info("Zpool - Disks" + @extract_disks.flatten.to_s + " are already in a pool as seen by all_vdevs of: " + all_vdevs.to_s + ", so skipping any actions on them.") 
        next
      end
    



      unless created_actual?
        unless online_actual?
          # the pool needs to be created.         
          shell_out!("zpool create #{args_from_resource(new_resource)} #{@zpool.name} #{@extract_path.join(' ')} #{@extract_disks.join(' ')}")
          new_resource.updated_by_last_action(true)
          wait_for_created_and_online
        else
        Chef::Log.warn("Zpool #{@zpool.name} is mmm #{state_actual}")
        end
      else
        #an existing pool needs to be added to.
        Chef::Log.info("Zpool - Need only to add...: zpool add #{args_from_resource(new_resource)} #{@zpool.name} #{@extract_path.join(' ')} #{@extract_disks.join(' ')}")
        shell_out!("zpool add #{args_from_resource(new_resource)} #{@zpool.name} #{@extract_path.join(' ')} #{@extract_disks.join(' ')}")
        new_resource.updated_by_last_action(true)  
      end
    end
  else
    Chef::Log.info("Zpool - No zpool entities found for #{@zpool.name}.")
  end # end for "entities"
end #end for "Action Create"

action :destroy do
  if created?
    Chef::Log.info("Zpool - Destroying zpool #{@zpool.name}")
    shell_out!("zpool destroy #{args_from_resource(new_resource)} #{@zpool.name}")
    new_resource.updated_by_last_action(true)
  end
end

private

def args_from_resource(new_resource)
  args = []
  args << '-f' if new_resource.force
  args << '-r' if new_resource.recursive

  # Properties
  args << '-o'
  args << format('ashift=%s', new_resource.ashift)

  args.join(' ')
end

def created?
  @zpool.info.exitstatus.zero?
end

def online?
  @zpool.state == 'ONLINE'
end

def created_actual?
  Chef::Log.info("Zpool - entered created_actual func") 
  extis_status = shell_out("zpool list -H -o health #{@zpool.name}").exitstatus.zero?
  if extis_status == true
    Chef::Log.info("Zpool - created_actual - extis_status: #{extis_status}") 
    return true
  else
    Chef::Log.info("Zpool - created_actual - extis_status: #{extis_status}") 
    return  false
  end
end

def online_actual?
  Chef::Log.info("Zpool - entered online_actual func") 
  extis_status = shell_out("zpool list -H -o health #{@zpool.name}").stdout.chomp
  if extis_status == 'ONLINE'
    Chef::Log.info("Zpool - online_actual - extis_status: #{extis_status}") 
    return true
  else
    Chef::Log.info("Zpool - online_actual - extis_status: #{extis_status}") 
    return false
  end
end

def state
  @zpool.info.stdout.chomp
end

def state_actual
  shell_out("zpool list -H -o health #{@zpool.name}").stdout.chomp
end

def info
  shell_out("zpool list -H -o health #{@zpool.name}")
end

def vdevs
  @vdevs ||= shell_out("zpool list -v -H #{@zpool.name}").stdout.lines.map do |line|
    # Chef::Log.info("Zpool - vdevs - line.chomp is:" + line.chomp.to_s) 
    next unless line.chomp =~ /^[\t]/
    # Chef::Log.info("Zpool - vdevs - line.comp.split(t) is:" + line.chomp.split("\t")[1].to_s) 
    line.chomp.split("\t")[1]
  end.compact
  @vdevs
end
def all_vdevs
  # Chef::Log.info("Zpool - entered all_vdevs func") 
  used_devices = []
  @all_vdevs ||= shell_out("zpool list -H -v").stdout.lines.map do |line|
    next unless line.chomp =~ /^[\t]/
    line.chomp.split("\t")[1]
  end.compact
  @all_vdevs
  # Chef::Log.info("Zpool - @all_vdevs is now:" + @all_vdevs.to_s)
end

def sanity?
  Chef::Log.info("Zpool - entered sanity func") 
  if @zpool.disks.empty? and @zpool.entities.empty?
    Chef::Application.fatal!("Zpool - ERROR! You cannot ask for a pool and define no disks or entities to create it from.")
  end
  duplicity = []
  flat_entities = []
  duplicity << extract_short_name(@zpool.disks)
  
  disks_from_entities = handle_layer(@zpool.entities, [], "disks")
  # Chef::Log.info("Zpool - Sanity - disks_from_entities from handle_layer: " + disks_from_entities.to_s)
  Chef::Log.info("Zpool - Sanity - disks_from_entities from handle_layer flatten: " + disks_from_entities.flatten.to_s)
  disks_from_entities.flatten.each do |disk|
    Chef::Log.info("Zpool - Sanity - Working on disk: " + disk.to_s)
    flat_entities << extract_short_name(disk)
  end
  duplicity << flat_entities.flatten
  Chef::Log.info("Zpool - duplicity is: " + duplicity.to_s + ".")
  if !duplicity.empty? and !duplicity.flatten.select{|not_uniq| duplicity.flatten.count(not_uniq) > 1}.uniq.empty?
    Chef::Application.fatal!("Zpool - You must NOT assign a device twice. Duplicate assignment detected for: " + duplicity.flatten.select{|not_uniq| duplicity.flatten.count(not_uniq) > 1}.uniq.to_s + ".", 42) 
  end
  duplicity.flatten.each do |disk|
    if @zpool.graceful == false and disk != "cache" and disk != "log" and disk != "mirror" and !disk =~ /^[raid]/ and !::File.exist?("/dev/" + disk)
      Chef::Application.fatal!("Zpool - How are you planning on creating a zpool when device \"" + disk.to_s + "\" is missing from the system?", 42)
    elsif @zpool.graceful == true
        Chef::Log.info("Zpool - How are you planning on creating a zpool when device \"" + disk.to_s + "\" is missing from the system? sending a \"Next\" and hoping for the best.")
        next
    end
    if disk != "cache" and disk != "log" and disk != "mirror" and !disk =~ /^[raid]/ and !::File.exist?("/dev/" + disk)
      Chef::Log.info("Zpool - How are you planning on creating a zpool when device \"" + disk.to_s + "\" is missing from the system?")
      Chef::Log.info("Zpool - Sending a \"next\" for this action")
      next
    end
  end
end

def extract_short_name(workingset)
  # Chef::Log.info("Zpool - entered extract_short_name func")
  scrapping = []
  if workingset.kind_of?(Array)
    workingset.each do |disk|
     short_disk = disk.split('/').last
     scrapping << short_disk unless disk == "mirror" or disk =~ /^[raid]/
    end
  else
    scrapping = workingset.split('/').last unless workingset == "mirror" or workingset =~ /^[raid]/
  end
  # Chef::Log.info("Zpool - extract_short_name - scrapping is: #{scrapping}")
  return scrapping
end

def wait_for_created_and_online
  # Chef::Log.info("Zpool - entered wait_for_created_and_online func")
  retry_count = 5
  loop do
    Chef::Log.info("Zpool - start of loop")
    if shell_out("zpool list -H -o health #{@zpool.name}").stdout.chomp == 'ONLINE'
      Chef::Log.info("Zpool - the pool is created and online")
      break
    else
      Chef::Log.info("Zpool - the pool is NOT created and NOT online")
      sleep 2
    end
    retry_count -= 1
    if retry_count == 0
      break
    end
  end
end

def handle_layer(obj, parent_types, desired_return)
  devices_to_return = []
  path_to_return =[]
  Chef::Log.info("Zpool - entered handle_layer func with obj: " + obj.to_s + " and parent_types of: " + parent_types.to_s )
  obj.each do |type,v|
      if parent_types.kind_of?(String)
        path = parent_types.split
      else
        path = parent_types.flatten
      end
      path << type
      path_to_return << path.flatten
      if v.kind_of?(Array)
        devices_to_return << v
      elsif v.kind_of?(Hash)
          handle_layer(v, path, desired_return )
      else 
          Chef::Application.fatal!("Zpool - ERROR! entities hash contains unsupported objects", 42)
      end 
  end
  case desired_return
    when "full"
      return [path_to_return, extract_short_name(devices_to_return.flatten)]
    when "disks"
      return extract_short_name(devices_to_return.flatten)
    when "path"
      return path_to_return.flatten
    else
      Chef::Application.fatal!("Zpool - ERROR! incorrect use of handle_layer func", 42)
  end
end