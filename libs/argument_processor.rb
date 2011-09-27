#GPL 2.0  http://www.gnu.org/licenses/gpl-2.0.html
#Zabbix CLI Tool and associated files
#Copyright (C) 2009,2010 Andrew Nelson nelsonab(at)red-tux(dot)net
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

require 'zbxapi/zdebug'
require 'zbxapi/exceptions'
require 'libs/zabcon_exceptions'
require 'libs/zabcon_globals'
require 'libs/command_tree'



# All functions for argument processing are in alphabetical order except for default functions which are placed first
module ArgumentProcessor

  class ParseError < Exception
  end

  # converts item to the appropriate data type if need be
  # otherwise it returns item
  def convert_or_parse(item)
    return item if item.class==Fixnum
    if item.to_i.to_s==item
      return item.to_i
    elsif item =~ /^"(.*?)"$/
      text=Regexp.last_match(1)
      return text
    elsif item =~ /^\[(.*?)\]$/
      array_s=Regexp.last_match(1)
      array=array_s.split2(:split_char=>',')
      results=array.collect do |i|
        i.lstrip!
        i.rstrip!
        convert_or_parse(i)
      end
      return results
    elsif item.class==String && (item.downcase=="true" || item.downcase=="false")
      return true if item.downcase=="true"
      return false
    else
      array=item.split2(:split_char=>',')
      if !array.nil? && array.length<=1
        return item
      else
        return array
      end
    end
  end

  # Params to hash breaks up an incoming line into individual elements.
  # It's kinda messy, and could probably one day use some cleaning up
  # The basic concept is it will return a hash based on what it finds.
  # If it finds an = character it will make a hash out of the left and right
  # if items are found inside quotes they will be treated as one unit
  # If items are found individually (not quoted) it will be put in a hash as the
  # left side with a value of true
  #
  # TODO this could use some cleanup.
  def params_to_hash(line)
    params=line.split2

    retval = {}
    params.each do |item|
      item.strip!
      if item =~ /^(.*?)=(.*?)$/ then
        Regexp.last_match
        lside=Regexp.last_match(1)
        rside=convert_or_parse(Regexp.last_match(2))
        if rside.class==Array  #check to see if we have hashes inside the array
          rside.collect! do |i|
            if i =~ /\{(.*)\}/
              params_to_hash(Regexp.last_match(1))
            else
              convert_or_parse(i)
            end
          end
        end

        if lside =~ /^"(.*?)"$/
          lside=Regexp.last_match(1)
        end

        if rside =~ /\{(.*)\}/
          rside=params_to_hash(Regexp.last_match(1))
        end

        if rside =~ /\[(.*)\]/
          Regexp.last_match(1)
          rside=[params_to_hash(Regexp.last_match(1))]
        end

        retval.merge!(lside=>rside)
      else
         if item =~ /^"(.*?)"$/
            item=Regexp.last_match(1)
         end
            retval.merge!(item=>true)
      end
    end
    retval
  end

  def params_to_hash2(line)
    params=line.split2
    p line


    params.map { |item|
      item.strip!
      if item =~ /^(.*?)=(.*)$/ then
        Regexp.last_match
        lside=Regexp.last_match(1)
        rside=Regexp.last_match(2)
        {lside=>params_to_hash2(rside)}
      else
        {item=>true}
      end
    }
  end

    #substitute_vars
  #This function will substitute the variable tokens in the string args for the values in the global object
  #GlobalVars
  def substitute_vars(args)

    #split breaks a string into an array  of component pieces which makes it easier to perform substitutions
    #in the present situation the component pieces are variables and non-variables.
    #whitespace is preserved in this split process
    def split(str)
      return [] if str.nil? or str.empty?
      #The function originally would split out quoted strings which would not be scanned
#      if result=/\\["']/.match(str)  # split out escaped quotes
#        return split(result.pre_match) + [result[0]] + split(result.post_match)
#      end
#      if result=/((["'])[^"']+\2)/.match(str)  #split out legitimately quoted strings
#        return split(result.pre_match) + [result[0]] + split(result.post_match)
#      end
#      if result=/["']/.match(str)  #split out dangling quotes
#        return split(result.pre_match) + [result[0]] + split(result.post_match)
#      end
#      if result=/\s+/.match(str)  #split on whitespace (this way we can preserve it)
#        return split(result.pre_match) + [result[0]] + split(result.post_match)
#      end
      if result=/[\\]?\$[A-Za-z]\w*/.match(str)  #split on variables
        return split(result.pre_match) + [result[0]] + split(result.post_match)
      end
      return [str]  #return what's left
    end

    # A variable is something that starts with a $ character followed by a letter then followed zero or more letters or
    # numbers
    # Variable substitution comes from the global singleton GlobalVars
    def substitute(args)
      args.map { |val|
        if result=/^\$([A-Za-z]\w*)/.match(val)
          GlobalVars.instance[result[1]]
        else
          val
        end
      }
    end

    #Removes the escaping on the $ character which is used to prevent variable substitution
    def unescape(args)
      args.gsub(/\\\$/, '$')
    end

    debug(2,:msg=>"Pre substitution",:var=>args)
    args=unescape(substitute(split(args)).join)
    debug(2,:var=>args,:msg=>"Post substitution")

    return args
  end


  # This is the default Parameter processor.  This is passed to the Command Tree object when it is instantiated
  # The default processor also checks the incoming parameters against a list of valid arguments, and merges
  # the user variables with the inbound arguments with the inbound arguments taking precedence, raises an
  # exception if there is an error
  # arg_info should be a hash containing two keys, :required_args, :valid_args
  # If :use_array_processor is passed as an option the array processor will be used
  # In :num_args is passed with a value, and error will be returned if more than that many args are passed

  def default_processor(args,arg_info,flags={})
    args=args.strip  #remove preceding and trailing whitespace
    #valid_args=arg_info[:valid_args]
    #required_args=arg_info[:required_args]
    invalid_args=[]

    if flags[:not_empty]
      raise ParameterError.new("No arguments",:retry=>true) if args.empty?
    end

    if flags[:array_params]
      args=args.split2
    elsif flags[:string_params]
      args=args
    else
      args=params_to_hash(args)

      if !arg_info[:valid_args].empty?
        args_keys=args.keys

        invalid_args=args_keys-arg_info[:valid_args] if arg_info[:valid_args]
        raise ParameterError.new("Invalid parameters: "+invalid_args.join(", "),
                                 :retry=>true) if !invalid_args.empty?

        required_args=arg_info[:required_args].reject{|i| i.class==Array }
        required_or_args=arg_info[:required_args].reject{|i| i.class!=Array }

        missing_args=[]
        missing_args=required_args-args_keys

        required_or_args.delete_if do |i|
          count=i.length
          missing_args<<i if (i-args_keys).count==count
        end

        if !missing_args.empty?
          msg=missing_args.map do |i|
            if i.class==Array
              "(#{i.join(" | ")})"
            else
              i
            end
          end.join(", ")
          raise ParameterError.new("Missing required arguments: #{msg}",:retry=>true)
        end
      end
    end
    Command::Arguments.new(args, flags)
  end

#  # This processor does not do anything fancy.  All items passed in via args are passed back in api_params
#  def simple_processor(help_func,valid_args,args,user_vars,*options)
#
#    args=substitute_vars(args)
#    args=params_to_hash(args)
#
#    {:api_params=>args, :show_params=>{}}
#  end
#
#  # This is the default processor for get commands.  It adds "limit" and "extendoutput" as needed
#  def default_get_processor(help_func, valid_args, args, user_vars, *options)
#
#    # let the default processor set things up
#    retval=default_processor(help_func,valid_args,args,user_vars,options)
#
#    if retval[:api_params]["limit"].nil?
#      retval[:api_params]["limit"]=100
#    end
#    if retval[:api_params]["show"].nil?
#      retval[:api_params]["extendoutput"]=true
#    end
#
#      retval
#  end
#
#  #Helper function to ensure the proper hash is returned
#  def return_helper(parameters,show_parameters=nil)
#    {:api_params=>parameters, :show_params=>show_parameters}
#  end
#
#  # Helper function the check for required parameters.
#  # Parameters is the hash of parameters from the user
#  # required_parameters is an array of parameters which are required
#  # returns an array of missing required items
#  # if the returned array is empty all required items found
#  def check_required(parameters,required_parameters)
#    r_params=required_parameters.clone    # Arrays are pass by reference
#    parameters.keys.each{|key| r_params.delete(key)}
#    r_params
#  end
#
#  # Helper function to check the validity of the parameters from the user
#  # Parameters is the hash of parameters from the user
#  # valid_parameters is an array of parameters which are valid
#  # returns an array of invalid parameters
#  # if the returned array is empty all parameters are valid
#  def check_parameters(parameters,valid_parameters)
#    if !valid_parameters.nil?
#      keys=parameters.keys
#      valid_parameters.each {|key| keys.delete(key)}
#      return keys
#    else
#      return []
#    end
#  end
#
#  # hash_processor is a helper function which takes the incoming arguments
#  # and chunks them into a hash of pairs
#  # example:
#  # input:  one two three four
#  # result:  "one"=>"two", "three"=>"four"
#  # Exception will be raised when error found
#  # processor does not do variable substitution
#  # TODO: Consider removing function as it appears not be used
#  def hash_processor(help_func,valid_args,args,user_vars,*options)
#    debug(6,options,"Options")
#    items=args.split2
#    if items.count % 2 == 0
#      rethash={}
#      while items.count!=0
#        rethash[items[0]]=items[1]
#        items.delete_at(0)
#        items.delete_at(0)   #make sure we delete the first two items
#      end
#      return_helper(rethash)
#    else
#      msg="Invalid input\n"
#      msg+="Odd number of arguments found"
#      raise ParameterError.new(msg,:retry=>true)
#    end
#  end
#
#  ##############################################################################################
#  # End of default and helper functions
#  ##############################################################################################
#
#  def add_user(help_func,valid_args,args, user_vars, *options)
#    debug(4,args,"args")
#
#    if args.empty?
#      call_help(help_func)
#      raise ParameterError.new("No arguments",:retry=>true, :help_func=>help_func)
#    end
#
#    valid_parameters=['name', 'surname', 'alias', 'passwd', 'url', 'autologin',
#                      'autologout', 'lang', 'theme', 'refresh', 'rows_per_page', 'type']
#    default_processor(help_func,valid_parameters,args,user_vars,options)
#  end
#
#  def add_host(help_func,valid_args,args,user_vars,*options)
#    debug(4,args,"args")
#    debug(4,options,"options")
#
#    if args.empty?
#      call_help(help_func)
#      return nil
#    end
#
#    #TODO, add the ability for both groups and groupids
#
#    valid_parameters=['host', 'groups', 'port', 'status', 'useip', 'dns', 'ip',
#                       'proxy_hostid', 'useipmi', 'ipmi_ip', 'ipmi_port', 'ipmi_authtype',
#                       'ipmi_privilege', 'ipmi_username', 'ipmi_password', 'templates']
#
#    parameters=default_processor(help_func,valid_parameters,args,user_vars,options)[:api_params]
#
#    required_parameters=[ 'host', 'groups' ]
#
##    p required_parameters
##    p parameters
#
##    if !parameters["dns"].nil? and !required_parameters.find("ip")
##      required_parameters.delete("ip")
##    elsif !parameters["ip"].nil? and !required_parameters["dns"]
##      required_parameters.delete("dns")
##    end
#
#    if !(missing=check_required(parameters,required_parameters)).empty?
##      if !required_parameters["ip"].nil? and !required_parameters["dns"].nil?
##        puts "Missing parameter dns and/or ip"
##        required_parameters["ip"].delete
##        required_parameters["dns"].delete
##      end
#      msg = "Required parameters missing\n"
#      msg += missing.join(", ")
#
#      raise ParameterError_Missing.new(msg,:retry=>true, :help_func=>help_func)
#    end
#
#    groups=convert_or_parse(parameters['groupids'])
#    if groups.class==Fixnum
#      parameters['groups']=[{"groupid"=>groups}]
#    end
#
#    return_helper(parameters)
#  end
#
#  def add_item_active(help_func,parameters,*options)
#    valid_parameters = ['hostid','description','key','delta','history','multiplier','value_type', 'data_type',
#                         'units','delay','trends','status','valuemapid','applications']
#    required_parameters = ['hostid','description','key']
#  end
#
#  def add_item(help_func,valid_args,args,user_vars,*options)
#    debug(4,args,"args")
#    debug(4,options,"options")
#    debug(4,user_vars,"User Variables")
#
#    if args.empty?
#      call_help(help_func)
#      return nil
#    end
#
#    #  Item types
#    #  0 Zabbix agent             - Passive
#    #  1 SNMPv1 agent             - SNMP
#    #  2 Zabbix trapper           - Trapper
#    #  3 Simple check             - Simple
#    #  4 SNMPv2 agent             - SNMP2
#    #  5 Zabbix internal          - Internal
#    #  6 SNMPv3 agent             - SNMP3
#    #  7 Zabbix agent (active)    - Active
#    #  8 Zabbix aggregate         - Aggregate
#    # 10 External check           - External
#    # 11 Database monitor         - Database
#    # 12 IPMI agent               - IPMI
#    # 13 SSH agent                - SSH
#    # 14 TELNET agent             - Telnet
#    # 15 Calculated               - Calculated
#
#    #value types
#    # 0 Numeric (float)
#    # 1 Character
#    # 2 Log
#    # 3 Numeric (unsigned)
#    # 4 Text
#
#    # Data Types
#    # 0 Decimal
#    # 1 Octal
#    # 2 Hexadecimal
#
#    # Status Types
#    # 0 Active
#    # 1 Disabled
#    # 2 Not Supported
#
#    # Delta Types
#    # 0 As is
#    # 1 Delta (Speed per second)
#    # 2 Delta (simple change)
#
#
#    valid_parameters= ['hostid', 'snmpv3_securitylevel','snmp_community', 'publickey', 'delta', 'history', 'key_',
#                        'key', 'snmp_oid', 'delay_flex', 'multiplier', 'delay', 'mtime', 'username', 'authtype',
#                        'data_type', 'ipmi_sensor','snmpv3_authpassphrase', 'prevorgvalue', 'units', 'trends',
#                        'snmp_port', 'formula', 'type', 'params', 'logtimefmt', 'snmpv3_securityname',
#                        'trapper_hosts', 'description', 'password', 'snmpv3_privpassphrase',
#                        'status', 'privatekey', 'valuemapid', 'templateid', 'value_type', 'groups']
#
#    parameters=default_processor(help_func,valid_parameters,args,user_vars,options)[:api_params]
#
##    valid_user_vars = {}
##
##    valid_parameters.each {|item|
##      valid_user_vars[item]=user_vars[item] if !user_vars[item].nil?
##    }
##    p parameters
##    p valid_user_vars
##    parameters = valid_user_vars.merge(parameters)
##    p parameters
#
#    required_parameters=[ 'type' ]
#
#    if parameters["type"].nil?
#      puts "Missing required parameter 'type'"
#      return nil
#    end
#
#    if !(invalid=check_parameters(parameters,valid_parameters)).empty?
#      puts "Invalid items"
#      puts invalid.join(", ")
#      return nil
#    end
#
#    case parameters["type"].downcase
#      when "passive"
#        parameters["type"]=0
#        required_parameters = ['hostid','description','key']
#      when "active"
#        parameters["type"]=7
#        required_parameters = ['hostid','description','key']
#      when "trapper"
#        parameters["type"]=2
#        required_parameters = ['hostid','description','key']
#    end
#
#    if !(missing=check_required(parameters,required_parameters)).empty?
#      puts "Required parameters missing"
#
#      puts missing.join(", ")
#
#      return nil
#    end
#
#    # perform some translations
#
#    parameters["key_"]=parameters["key"]
#    parameters.delete("key")
#
#    return_helper(parameters)
# end
#
#
#  def delete_host(help_func,valid_args,args,user_vars,*options)
#    debug(6,args,"args")
#
#    args=default_processor(help_func,valid_args,args,user_vars,options)[:api_params]
#
#    if args["id"].nil?
#      puts "Missing parameter \"id\""
#      call_help(help_func)
#      return nil
#    end
#
#    return_helper(args["id"])
#  end
#
#  def delete_user(help_func,valid_args,args,user_vars,*options)
#    debug(6,args,"args")
#    if (args.split(" ").length>1) or (args.length==0)
#      raise ParameterError("Incorrect number of parameters",:retry=>true, :help_func=>help_func)
#    end
#
#    args=default_processor(help_func,valid_args,args,user_vars)[:api_params]
#
#    if !args["id"].nil?
#      return return_helper(args) if args["id"].class==Fixnum
#      puts "\"id\" must be a number"
#      call_help(help_func)
#      return nil
#    end
#
#    puts "Invalid arguments"
#    call_help(help_func)
#    return nil
#
#  end
#
#  #TODO: Document why this function does not use the default processor
#  def get_group_id(help_func,valid_args,args,user_vars,*options)
#    debug(4,valid_args,"valid_args")
#    debug(4,args,"args")
#
#    args=substitute_vars(args)
#    args=params_to_hash(args)
#
#    {:api_params=>args.keys, :show_params=>nil}
#  end
#
#  def get_user(help_func,valid_args,args,user_vars,*options)
#    debug(4,valid_args,"valid_args")
#    debug(4,args, "args")
#
#    retval=default_get_processor(help_func,valid_args,args,user_vars)
#    error=false
#    msg=''
#
#    if !retval[:show_params][:show].nil?
#      show_options=retval[:show_params][:show]
#      if !show_options.include?("all")
#        valid_show_options=['name','attempt_clock','theme','autologout','autologin','url','rows_per_page','attempt_ip',
#                            'refresh','attempt_failed','type','userid','lang','alias','surname','passwd']
#
#        invalid_show_options=show_options-valid_show_options
#
#        if invalid_show_options.length!=0
#          error=true
#          msg = "Invalid show options: #{invalid_show_options}"
#        end
#      elsif show_options.length!=1
#        error=true
#        msg = "Show header option \"all\" cannot be included with other headers"
#      end
#    end
##    raise ParameterError(msg,help_func) if error
#
#    return retval
#  end
#
#  #TODO: Use helper functions to make login more robust
#  def login(help_func,valid_args,args,user_vars,*options)
#    debug(4,args, "args")
#    args=args.split
#    if args.length!=3
#      call_help(help_func)
#      return nil
#    end
#    params={}
#    params[:server]=args[0]
#    params[:username]=args[1]
#    params[:password]=args[2]
#    return {:api_params=>params}
#  end
#
#  def raw_api(help_func,valid_args,args,user_vars,*options)
#    debug(7,args,"raw_api argument processor")
#
#    args=substitute_vars(args)
#
#    items=args.split2
#    method=items[0]
#    items.delete_at(0)
#    args=items.join(" ")
#    args=params_to_hash(args)
#    args=nil if args=={}
#
#    {:api_params=>{:method=>method, :params=>args}, :show_params=>{}}
#  end

end


if __FILE__ == $0

  #If we don't have the each_char method for the string class include the module that has it.
  if !String.method_defined?("each_char")
    require 'jcode'
  end

  require 'pp'

  include ZDebug
  set_debug_level(1)
  arg_processor=ArgumentProcessor.new

  p arg='i1=2 i2=item i3="this is a short sentence" i4="a string with a \" char"'
  pp arg_processor.params_to_hash(arg),"----"

  p arg='one=-2 two="" three=1,2 four=[1,2,three]'
  pp arg_processor.params_to_hash(arg),"----"

  p arg='hosts=[{hostid=10017}] name="zzz"'
  pp arg_processor.params_to_hash(arg)
end
