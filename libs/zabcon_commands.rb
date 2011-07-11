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

ZabconCommand.add_command "get host" do
  set_method {|params|
    server.connection.host.get(params)
  }
  default_show ["hostid", "host", "dns", "ip"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_host
end

#      @commands.insert ["get","host","group"], @server.method(:gethostgroup), no_args, no_help, @arg_processor.default_get

ZabconCommand.add_command "get host group" do
  set_method { |params|
    server.connection.hostgroup.get(params)
  }
  default_show ["groupid", "name"]
  set_flag :print_output
  set_help_tag :get_host_group
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

ZabconCommand.add_command "get trigger" do
  set_method { |params|
    server.connection.trigger.get(params)
  }
  default_show ["triggerid","description", "status"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_trigger
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