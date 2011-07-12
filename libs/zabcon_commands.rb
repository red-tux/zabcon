#License:: GPL 2.0  http://www.gnu.org/licenses/gpl-2.0.html
#Copyright:: Copyright (C) 2009,2010 Andrew Nelson nelsonab(at)red-tux(dot)net
#
#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

##########################################
# Subversion information
# $Id$
# $Revision$
##########################################

require "libs/zdebug"


ZabconCommand.add_command "exit" do
  set_method {
    puts "Exiting"
    throw :exit
  }
  set_help_tag :exit
  add_alias "quit"
end

ZabconCommand.add_command "help" do
  set_method { |params|
    if params.empty?
      puts CommandHelp.get(:help)
    else
      cmd=CommandList.instance.get(params)
      tag=!cmd.nil? ? cmd.help_tag : :_unknown
      if tag==:_unknown or tag==:_none
        puts "Unable to find help for: \"#{params.join(" ")}\""
      else
        puts CommandHelp.get(tag)
      end
    end
  }
  set_flag :array_params
  set_help_tag :help
end

ZabconCommand.add_command "help commands" do
  set_method {
    CommandList.instance.get_command_list.each {|item|
      puts item
    }
  }
  set_help_tag :help_commands
end

ZabconCommand.add_command "login" do
  set_method { |params|
#    login server username password
    server.server_url=params[0]
    server.username=params[1]
    server.password=params[2]
    server.login
  }
  set_help_tag :help
  set_flag :array_params
end

ZabconCommand.add_command "logout" do
  set_method {
    server.logout
  }
  set_help_tag :logout
end

ZabconCommand.add_command "info" do
  set_method{
    puts "Current settings"
    puts "Server"
    if !server.connected?
      puts "Not connected"
    else
      puts " Server Name: %s" % server.server_url
      puts " Username: %-15s Password: %-12s" % [server.username, Array.new(server.password.length,'*')]
    end
    puts "Display"
    puts " Current screen length #{env["sheight"]}"
    puts "Other"
    puts " Debug level %d" % env["debug"]
  }
  set_help_tag :info
end

ZabconCommand.add_command "set env" do
  set_method { |params|

    params.each{|key,val|
    env[key]=val
    puts "#{key} : #{val.inspect}"
    }
  }
  set_help_tag :set_env
end

ZabconCommand.add_command "load config" do
  set_method { |params|
    env.load_config(params)
  }
  set_help_tag :load_config
end

ZabconCommand.add_command "set debug" do
  set_method{ |params|
  env["debug"]=params[0]}
  set_flag :array_params
  set_help_tag :set_debug
end

ZabconCommand.add_command "show var" do
  set_method { |params|
    if params.empty?
      if GlobalVars.instance.empty?
        puts "No variables defined"
      else
        GlobalVars.instance.each { |key,val|
          puts "#{key} : #{val.inspect}"
        }
      end
    else
      params.each { |item|
        if GlobalVars.instance[item].nil?
          puts "#{item} *** Not Defined ***"
        else
          puts "#{item} : #{GlobalVars.instance[item].inspect}"
        end
      }
    end
  }
  set_help_tag :show_var
  set_flag :array_params
end

ZabconCommand.add_command "show env" do
  set_method { |params|
    if params.empty?
      if env.empty?
        puts "No variables defined"
      else
        env.each { |key,val|
          puts "#{key} : #{val.inspect}"
        }
      end
    else
      params.each { |item|
        if env[item].nil?
          puts "#{item} *** Not Defined ***"
        else
          puts "#{item} : #{env[item].inspect}"
        end
      }
    end
  }
  set_help_tag :show_env
  set_flag :array_params
end

ZabconCommand.add_command "raw api" do
  set_method {|params|
    api_func=params[:method]
    params=params[:params]

    server.connection.raw_api(api_func, params)
  }

  arg_processor {|*params|
    parameter_error "Command \"raw api\" requires parameters" if params.empty?
    params=params[0].split2
    api_func=params[0]
    params.delete_at(0)
    retval= params_to_hash(params.join(" "))
    {:method=>api_func, :params=>retval}
  }
  set_flag :login_required
  set_flag :print_output
  set_help_tag :raw_api
end

###############################################################################
#Application                                                       Application#
###############################################################################

ZabconCommand.add_command "add app" do
  set_method {|params|
    server.connection.application.create(params)
  }
  set_flag :login_required
  set_flag :print_output
  set_help_tag :add_app
end


ZabconCommand.add_command "get app" do
  set_method {|params|
    server.connection.application.get(params)
  }
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_app
end

###############################################################################
#Host                                                                     Host#
###############################################################################

ZabconCommand.add_command "add host" do
  set_method {|params|
#    {:class=>:host, :message=>"The following host was created: #{result['hostids']}", :result=>result}
    server.connection.host.create(params)
  }
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_host
end

ZabconCommand.add_command "get host" do
  set_method {|params|
    server.connection.host.get(params)
  }
  default_show ["hostid", "host", "dns", "ip"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_host
end

ZabconCommand.add_command "get host group" do
  set_method { |params|
    server.connection.hostgroup.get(params)
  }
  default_show ["groupid", "name"]
  set_flag :print_output
  set_help_tag :get_host_group
end

###############################################################################
#Item                                                                     Item#
###############################################################################


ZabconCommand.add_command "add item" do
  set_method { |params|
    server.connection.item.create(params)
  }
  set_flag :login_required
  set_flag :print_output
  set_help_tag :add_item
end


ZabconCommand.add_command "get item" do
  set_method { |params|
    server.connection.item.get(params)
  }
  set_valid_args ['itemids','hostids','groupids', 'triggerids','applicationids',
                  'status','templated_items','editable','count','pattern','limit',
                  'order', 'show']
  default_show ["itemid", "key", "description"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_item
end

###############################################################################
#Trigger                                                               Trigger#
###############################################################################

ZabconCommand.add_command "get trigger" do
  set_method { |params|
    server.connection.trigger.get(params)
  }
  default_show ["triggerid","description", "status"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_trigger
end

###############################################################################
#User                                                                     User#
###############################################################################

ZabconCommand.add_command "add user" do
  set_method { |params|
    uid=server.connection.user.create(params)
    puts "Created userid: #{uid["userids"]}"
  }
  set_flag :login_required
  set_help_tag :add_user
end

ZabconCommand.add_command "delete user" do
  set_method { |params|
    id=0
    if !params["name"].nil?
      users=server.connection.user.get({"pattern"=>params["name"], "extendoutput"=>true})
      users.each { |user| id=user["userid"] if user["alias"]==parameter }
    else
      id=params["id"]
    end
    result=@connection.user.delete(id)

    if !result.empty?
      puts "Deleted user id #{result["userids"]}"
    else
      puts "Error deleting #{params.to_a[0][1]}"
    end
  }
  set_flag :login_required
  set_help_tag :delete_user
end

ZabconCommand.add_command "get user" do
  set_method { |params|
    server.connection.user.get(params)
  }
  default_show ["userid","name","surname","alias"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_user
end
