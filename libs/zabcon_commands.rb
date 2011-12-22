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

require "zbxapi/zdebug"


ZabconCommand.add_command "exit" do
  set_method do
    puts "Exiting"
    throw :exit
  end
  set_help_tag :exit
  add_alias "quit"
end

ZabconCommand.add_command "help" do
  set_method do |params|
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
  end
#  set_flag :array_params
  set_help_tag :help
  tokenizer SimpleTokenizer
end

ZabconCommand.add_command "help commands" do
  set_method do
    CommandList.instance.get_command_list.each {|item|
      puts item
    }
  end
  set_help_tag :help_commands
end

ZabconCommand.add_command "login" do
  set_method do |params|
#    login server username password
    server.server_url=params[0]
    server.username=params[1]
    server.password=params[2]
    server.login
  end
  set_help_tag :help
#  set_flag :array_params
  tokenizer(SimpleTokenizer.options(:remove_whitespace))
  #arg_processor do |arg|
  #  puts "arg_processor method"
  #  p arg
  #  arg
  #end
end

ZabconCommand.add_command "set proxy" do
  set_method do |params|
    env["proxy_server"]=params[0]
    env["proxy_port"]=params[1] || env["proxy_port"] || 3128
    env["proxy_user"]=params[2]
    env["proxy_password"]=params[3]
  end
  set_help_tag :set_proxy
  tokenizer(SimpleTokenizer.options(:remove_whitespace))
end

ZabconCommand.add_command "logout" do
  set_method do
    server.logout
    path=File.expand_path(env["session_file"])
    begin
      File.delete(path)
    rescue Errno::ENOENT
    end
  end
  set_help_tag :logout
end

ZabconCommand.add_command "info" do
  set_method do
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
  end
  set_help_tag :info
end

ZabconCommand.add_command "set env" do
  set_method do |params|

    params.each { |key,val|
    env[key]=val
    puts "#{key} : #{val.inspect}"
    }
  end
  set_help_tag :set_env
end

ZabconCommand.add_command "load config" do
  set_method do |params|
    env.load_config(params)
  end
  set_help_tag :load_config
end

ZabconCommand.add_command "set debug" do
  set_method do |params|
    env["debug"]=params[0]
  end
  depreciated "set env debug=N"
#  set_flag :array_params
  set_help_tag :set_debug
  tokenizer SimpleTokenizer
end

ZabconCommand.add_command "set lines" do
  set_method do |params|
    env["lines"]=params[0]
  end
  depreciated "set env lines=N"
#  set_flag :array_params
  set_help_tag :set_lines
  tokenizer SimpleTokenizer
end

ZabconCommand.add_command "set pause" do
  set_method do |params|
    if params.nil? then
      puts "set pause requires either Off or On"
      return
    end

    if params.keys[0].upcase=="OFF"
      env["lines"]=env["lines"].abs*(-1)
    elsif params.keys[0].upcase=="ON"
      env["lines"]=env["lines"].abs
    else
      puts "set pause requires either Off or On"
    end
    env["lines"]=24 if env["lines"]==0
  end
#  set_flag :array_params
  set_help_tag :set_pause
  tokenizer SimpleTokenizer
end

ZabconCommand.add_command "show var" do
  set_method do |params|
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
  end
  set_help_tag :show_var
#  set_flag :array_params
  tokenizer SimpleTokenizer
end

ZabconCommand.add_command "show env" do
  set_method do |params|
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
  end
  set_help_tag :show_env
#  set_flag :array_params
  tokenizer SimpleTokenizer
end

ZabconCommand.add_command "set var" do
  set_method do |params|
    params.each { |key,val|
      GlobalVars.instance[key]=val
      puts "#{key} : #{val.inspect}"
    }
  end
  set_help_tag :set_var
end

ZabconCommand.add_command "unset var" do
  set_method do |params|
    if params.empty?
      puts "No variables given to unset"
    else
      params.each { |item|
        if GlobalVars.instance[item].nil?
          puts "#{item} *** Not Defined ***"
        else
          GlobalVars.instance.delete(item)
          puts "#{item} Deleted"
        end
      }
    end
  end
#  set_flag :array_params
  set_help_tag :unset_var
  tokenizer SimpleTokenizer
end

ZabconCommand.add_command "show revisions" do
  set_method do |params|
    revision_path=File.join(ZABCON_PATH,"revision_information")
    raise ZabconError.new("Revision file not found!",:retry=>true) if !File.file?(revision_path)
    revision_file=File.new(revision_path)
    while !revision_file.eof
      puts revision_file.gets
    end
    revision_file.close
  end
  set_help_tag :show_revision
end

ZabconCommand.add_command "raw api" do
  set_method do |params|
    api_func=params[0]
    params.delete_at(0)
    args={}
    if !params.empty?
      params.each { |param|
        if param.is_a?(Hash)
          args.merge!(param)
        else
          raise Command::ParameterError.new("Unexpected parameter \"#{param}\"")
        end
      }
    end
    server.connection.raw_api(api_func, args)
  end

  #arg_processor do |params,args,flags|
  #  debug(6,:var=>params)
  #  params=ExpressionTokenizer.new(params).parse
  #  parameter_error "Command \"raw api\" requires parameters" if params.empty?
  #  api_func=params[0]
  #  params.delete_at(0)
  #  params2={}
  #  params.each do |i|
  #    params2.merge!(i)
  #  end
  #  {:method=>api_func, :params=>params2}
  #end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :raw_api
  result_type :raw_api
  tokenizer CommandTokenizer
#  tokenizer SimpleTokenizer
end

ZabconCommand.add_command "raw json" do
  set_method do |params|
    begin
      result=server.connection.do_request(params)
      retval=result["result"]
    rescue ZbxAPI_GeneralError => e
      puts "An error was received from the Zabbix server"
      if e.message.class==Hash
        puts "Error code: #{e.message["code"]}"
        puts "Error message: #{e.message["message"]}"
        puts "Error data: #{e.message["data"]}"
      end
      puts "Original text:"
      puts params
      puts
      retval=nil
    end
    retval
  end
  #arg_processor do |params,args,flags|
  #  params
  #end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :raw_api
  result_type :raw_api
  tokenizer SimpleTokenizerString
end

###############################################################################
#Application                                                       Application#
###############################################################################

ZabconCommand.add_command "add app" do
  set_method do |params|
    server.connection.application.create(params)
  end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :add_app
end


ZabconCommand.add_command "get app" do
  set_method do |params|
    server.connection.application.get(params)
  end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_app
end

###############################################################################
#Host                                                                     Host#
###############################################################################

ZabconCommand.add_command "add host" do
  set_method do |params|
    result=server.connection.host.create(params)
    set_result_message "The following host was created: #{result['hostids']}"
    result
  end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :add_host
  result_type :host
end

ZabconCommand.add_command "delete host" do
  set_method do |params|
    result=server.connection.host.delete(params)
    set_result_message "The following host was deleted: #{result['hostids']}"
    result
  end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :delete_host
  result_type :host
end

ZabconCommand.add_command "get host" do
  set_method do |params|
    server.connection.host.get(params)
  end
  default_show ["hostid", "host", "dns", "ip"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_host
  result_type :host
end

ZabconCommand.add_command "update host" do
  set_method do |params|
    raise Command::NonFatalError.new("Update host requires a parameter to update.") if params.size<2

    #TODO Add host.update to the zbxapi library
    server.connection.raw_api("host.update",params)
  end

  set_valid_args 'hostid', 'proxy_hostid', 'host', 'dns', 'useip', 'ip',
                 'port', 'status', 'useipmi', 'ipmi_port', 'ipmi_authtype',
                 'ipmi_privilege', 'ipmi_username', 'ipmi_password',
                 'ipmi_ip'
  required_args "hostid"

#  default_show ["itemid", "key_", "description"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :update_user
  result_type :host
end


###############################################################################
#Host Group                                                         Host Group#
###############################################################################

ZabconCommand.add_command "add host group" do
  set_method do |params|
    groupid = server.connection.hostgroup.create(params)
    "Created host groupid: #{groupid["groupids"]}"
  end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :add_host_group
  result_type :host
end

ZabconCommand.add_command "get host group" do
  set_method do |params|
    server.connection.hostgroup.get(params)
  end
  default_show ["groupid", "name"]
  set_flag :print_output
  set_help_tag :get_host_group
  result_type :host
end

###############################################################################
#Item                                                                     Item#
###############################################################################


ZabconCommand.add_command "add item" do
  set_method do |params|
    server.connection.item.create(params)
  end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :add_item
  result_type :item
end

ZabconCommand.add_command "delete item" do
  set_method do |params|
    server.connection.item.delete(params)
  end
  set_flag :login_required
  set_flag :print_output
  set_help_tag :delete_item
  result_type :item
end


ZabconCommand.add_command "get item" do
  set_method do |params|
    server.connection.item.get(params)
  end
  set_valid_args 'itemids','hostids','groupids', 'triggerids','applicationids',
                  'status','templated_items','editable','count','pattern','limit',
                  'order', 'show'
  default_show ["itemid", "key_", "description"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_item
  result_type :item
end

###############################################################################
#Trigger                                                               Trigger#
###############################################################################

#TODO Improve parameter checking for add trigger
# addtrigger( { trigger1, trigger2, triggern } )
# Only expression and description are mandatory.
# { { expression, description, type, priority, status, comments, url }, { ...} }
ZabconCommand.add_command "add trigger" do
  set_method do |params|
    server.connection.trigger.create(params)
  end
  default_show ["triggerid","description", "status"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :add_trigger
  result_type :trigger
end

ZabconCommand.add_command "get trigger" do
  set_method do |params|
    server.connection.trigger.get(params)
  end
  default_show ["triggerid","description", "status"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_trigger
  result_type :trigger
end

###############################################################################
#User                                                                     User#
###############################################################################

ZabconCommand.add_command "add user" do
  set_method do |params|
    uid=server.connection.user.create(params)
    puts "Created userid: #{uid["userids"]}"
  end
  set_flag :login_required
  set_help_tag :add_user
  result_type :user
end

ZabconCommand.add_command "delete user" do
  set_method do |params|
    id=0
    if !params["name"].nil?
      users=server.connection.user.get({"pattern"=>params["name"], "extendoutput"=>true})
      users.each { |user| id=user["userid"] if user["alias"]==parameter }
    else
      id=params["id"]
    end
    result=server.connection.user.delete(id)

    if !result.empty?
      puts "Deleted user id #{result["userids"]}"
    else
      puts "Error deleting #{params.to_a[0][1]}"
    end
  end
  set_flag :login_required
  set_help_tag :delete_user
  result_type :user
end

ZabconCommand.add_command "get user" do
  set_method do |params|
    server.connection.user.get(params)
  end
  default_show ["userid","name","surname","alias"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :get_user
  result_type :user
end

#TODO Test this command
ZabconCommand.add_command "update user" do
  set_method do |params|
    if parameters.nil? or parameters["userid"].nil? then
      puts "Edit User requires arguments, valid fields are:"
      puts "name, surname, alias, passwd, url, autologin, autologout, lang, theme, refresh"
      puts "rows_per_page, type"
      puts "userid is a required field"
      puts "example:  edit user userid=<id> name=someone alias=username passwd=pass autologout=0"
      return nil
    else
      p_keys = parameters.keys

      valid_parameters.each {|key| p_keys.delete(key)}
      if !p_keys.empty? then
        puts "Invalid items"
        debug(8,p_keys)
        return false
      elsif parameters["userid"].nil?
        puts "Missing required userid statement."
      end
      server.connection.user.update([parameters])
    end
  end
  set_valid_args 'userid','name', 'surname', 'alias', 'passwd', 'url',
                  'autologin', 'autologout', 'lang', 'theme', 'refresh',
                  'rows_per_page', 'type'
  default_show ["itemid", "key_", "description"]
  set_flag :login_required
  set_flag :print_output
  set_help_tag :update_user
  result_type :user
end

###############################################################################
#Special                                                               Special#
###############################################################################


#ZabconCommand.add_command "add host" do
#  set_method do |params|
#    result=server.connection.host.create(params)
#    set_result_message "The following host was created: #{result['hostids']}"
#    result
#  end
#  set_flag :login_required
#  set_flag :print_output
#  set_help_tag :add_host
#  result_type :host
#end

ZabconCommand.add_command "clone host" do
  set_method do |params|
    source=params["source"]
    target=server.connection.host.get({"output"=>"extend", "filter"=>{"host"=>[params["host"]]}})
    if !target.empty?
      raise Command::NonFatalError.new("host #{params["host"]} already exists with hostid #{target[0]["hostid"]}")
    end
    source_info=server.connection.host.get({"output"=>"extend", "selectParentTemplates"=>"refer", "filter"=>{"host"=>[source]}})
    source_hostid=source_info[0]["hostid"]
    templates=source_info[0]["parentTemplates"].map{|i| i["hostid"] }
    groups=server.connection.hostgroup.get(
        {"hostids"=>[source_hostid],
         "output"=>"extend"}).map do |i| {"groupid"=>i["groupid"]}
    end
    result=server.connection.host.create({"host"=>params["host"],
      "ip"=>params["ip"],"useip"=>params["useip"],"groups"=>groups,
      "port"=>params["port"],
      "templates"=>templates.map {|i| {"templateid"=>i}} })
    result
  end

  required_args "host", ["ip","dns"], "useip", "port", "source"
  set_flag :login_required
  set_flag :print_output
  set_help_tag :clone_host
  result_type :host
end

