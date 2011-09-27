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

#--
##########################################
# Subversion information
# $Id$
# $Revision$
##########################################
#++

require 'singleton'
require 'libs/lexer'
require 'zbxapi/zdebug'
require 'libs/zabcon_exceptions'
require 'libs/zabcon_globals'
require 'libs/argument_processor'

class ZabconExecuteBase
  include ZDebug

  attr_reader :results

  def execute
    raise "Unitialized base method"
  end

end

class ZabconExecuteCommand < ZabconExecuteBase

  class NilCommand < Exception
  end

  #TODO Calling/showing help needs to be streamlined and cleaned up better
  class Help < Exception
    attr_reader :obj
    def initialize(obj)
      @obj=obj
    end

    def show_help
      @obj.help.call
    end
  end

  attr_reader :show_params, :options, :help

  #Configure the command item
  #Also perform the necessary argument processing at this step.
  def initialize(cmd_obj)
    raise "cmd_obj must be fo type CommandList::Cmd" if cmd_obj.class!=CommandList::Cmd

    @results=nil
    @proc=cmd_obj.command_obj.method(:execute)
    @command_obj=cmd_obj.command_obj
    begin
      arg_result=@command_obj.call_arg_processor(cmd_obj.parameters)
    #TODO Fix showing help messages
    #rescue ParameterError => e
    #  e.help_func=cmd_obj.command_obj.help_method
    #  raise e
    end
    @cmd_params=arg_result.cmd_params
    @show_params=arg_result.show_params
    @printing=cmd_obj.command_obj.print?
    @command_name=cmd_obj.command_obj.command_name
#    @help=cmd_obj.help
#    @options=options

  end

  def print?
    @printing==true
  end

  def execute

    @results=@command_obj.execute(@cmd_params)

  end
end

class ZabconExecuteVariable < ZabconExecuteBase
  def initialize(var)
    @var=var
  end

  def assign(val)
    @results=val
    GlobalVars.instance[@var]=val
  end

end

class ZabconExecuteContainer

  include ZDebug

  attr_reader :show_params, :results, :options

  def initialize(usr_str)
    @initial_string=usr_str
    @commands=[]
    @printing=true
    commandlist=CommandList.instance

    tokens=Tokenizer.new(usr_str)

    #split_str=usr_str.split2(:split_char=>'=|\s', :include_split=>true)
    #
    #unravel=false  #remove any extra space before the first =
    #split_str2=split_str.map {|item|
    #  if unravel
    #    item
    #  elsif item=="="
    #    unravel=true
    #    item
    #  elsif item.empty?
    #    nil
    #  elsif item.scan(/\s/).empty?
    #    item
    #  else
    #    nil
    #  end
    #}.delete_if {|i| i.nil?}
    #
    #if !split_str2[1].nil? && split_str2[1]=='='
    #  split_str=split_str2  #use the trimmed version
    #  var_name=split_str[0].strip
    #  raise ParseError.new("Variable names cannot contain spaces or invalid characters \"#{var_name}\"",:retry=>true) if !var_name.scan(/[^\w]/).empty?
    #
    #  debug(5,:var=>var_name,:msg=>"Creating Variable assignment")
    #  add(ZabconExecuteVariable.new(var_name))
    #
    #  usr_str=split_str[2..split_str.length-1].join.strip
    #  debug(5,:var=>usr_str,:msg=>"Continuging to parse with")
    #end
    #
    #debug(6,:var=>split_str,:msg=>"Split Str")
    #debug(6,:var=>split_str2,:msg=>"Split Str2")
    #debug(6,:var=>usr_str,:msg=>"User Str")
    pos=tokens.walk(0)
    if (positions=tokens.assignment?(pos,:return_pos=>true))
      var_name = tokens[positions[0]].value
      debug(5,:var=>var_name,:msg=>"Creating Variable assignment")
      add(ZabconExecuteVariable.new(var_name))
      tokens=tokens.drop(positions[2]+1)
    end

    cmd_str=tokens.map{|i| i.value}.join
    debug(5,:msg=>"Command String",:var=>cmd_str)
    cmd=commandlist.find_and_parse(cmd_str)
    add(ZabconExecuteCommand.new(cmd))

  end

  def print?
    @printing==true   #Ensure we get a boolean ;-)
  end

  def add(obj)
    raise "Expected ZabconExecuteCommand Class" if
        obj.class!=ZabconExecuteCommand &&
        obj.class!=ZabconExecuteVariable
    @commands<<obj
    if obj.class==ZabconExecuteCommand
      @printing=@printing & obj.print?
      @show_params=obj.show_params
      @options=obj.options
    end

  end

  def execute
    stack=[]
    ptr=0
    while ptr<@commands.length
      case @commands[ptr].class.to_s
        when "ZabconExecuteCommand"
          @commands[ptr].execute
          @results=@commands[ptr].results
        when "ZabconExecuteVariable"
          stack<<ptr
      end
      ptr+=1
    end

    while !stack.empty?
      ptr=stack.pop
      @commands[ptr].assign(@results)
    end
  end

end


#Command is the main class used to define commands in Zabcon which are then
#inserted into the global singleton class CommandList
class Command
  attr_reader :str, :aliases, :argument_processor, :flags
  attr_reader :required_args, :valid_args
  attr_reader :help_tag, :path

  include ArgumentProcessor

  #Class containing processed arguments to be passed to the command
  class Arguments
    class ParameterError < Exception
    end

    attr_accessor :cmd_params
    attr_reader :show_params

    def initialize(args, flags)
      if args.class==String
        @cmd_params=args
        @show_params=nil
      else
        raise "Unknown Argument Object type: #{args.class}" if args.class!=Array && args.class!=Hash

        @cmd_params=args
        @show_params = {}
        if args.class!=Array && (args["show"] || flags[:default_cols])
          show=args["show"] || flags[:default_cols]
          @show_params={:show=>show}
          @cmd_params.delete("show") if args["show"]
          @cmd_params.merge!({"extendoutput"=>true})
        end
      end
    end

    def show_params=(value)
      raise ParameterError.new("Show argument must be of type Array") if !vaue.is_a?(Array)
      @show_params=value
    end
  end

  class NonFatalError < Exception
  end

  class LoginRequired < Exception
  end

  class ParameterError < Exception
  end

  class ArgumentError < Exception
  end

  class LoopError < Exception
  end

  def initialize(path)
    raise "Path must be an array" if path.class!=Array
    @path=path
    @cmd_method=nil
    @valid_args=@required_args=[]
    @aliases=[]
    @flags={}
    @result_type=nil

    #TODO Can the argument processor stuff be cleaned up?
    @argument_processor=method(:default_processor)
    @help_tag=nil
    @depreciated=nil
  end

  def command_name
    @path.join(" ")
  end

  def print?
    if @flags.nil?
      false
    else
      @flags[:print_output]==true
    end
  end

  def set_method(&cmd_method)
    @cmd_method=cmd_method
  end

  #Adds an alias name for the current command
  def add_alias(name)
    @aliases<<name.split2
  end

  #How many alias' are there?
  def alias_total
    @aliases.length
  end

  def generate_alias(index)
    raise "Index out of bounds 0 >= i < N, i=#{index} N=#{alias_total}" if index<0 || index>=alias_total
    new_alias=self.dup
    new_alias.instance_variable_set("@path",@aliases[index])
    new_alias.instance_variable_set("@aliases",[])
    new_alias
  end

  #Sets up a list of required arguments
  #args is an array of items.  If there are multiple options
  #which are optional but one of which is required, it shall
  #be passed as a sub-array
  #example, host, useip are required, but only one of dns and ip is required
  #[host,useip,[dns,ip]]
  def required_args(*args)
    @required_args=args
    @valid_args=@valid_args|args.flatten
  end

  #accepts an array of valid arguments
  def set_valid_args(*args)
    @valid_args=@valid_args|args
  end

  def default_show(cols)
    raise "Cols must be an array" if cols.class!=Array
    @flags[:default_cols]=cols
  end

  def depreciated(str)
    @depreciated=str
  end

  def arg_processor(&block)
    @argument_processor=block
  end

  def set_arg_processor(method)
    @argument_processor=method
  end

  def set_help_tag(sym)
    @help_tag=sym
  end

  #--
  #TODO Complete type casting section and add error checking
  #++
  #Valid flags:
  # :login_required  - command requires a valid login
  # :print_output  - the output of the command will be passed to the print processor
  # :array_params  - Only process the parameters as an array
  def set_flag(flag)
    case flag.class.to_s
      when "Symbol"
        flag={flag=>true}
    end

    @flags.merge!(flag)
  end

  def call_arg_processor(parameters)
    def set_show_args(args)
      @arguments.show_params=args
    end

    @arguments=Arguments.new("",@flags)
    result=@argument_processor.call(parameters,{:valid_args=>@valid_args,:required_args=>@required_args},@flags)
    return result if result.is_a?(Arguments)
    if !result.is_a?(String) && !result.is_a?(Hash) && !result.is_a?(Array)
      raise ("Arugment processor for \"#{command_name}\" returned invalid parameters: class: #{result.class}, #{result}")
    else
      @arguments.cmd_params=result
      arguments=@arguments
      return arguments
    end
  end

  #Sets the symbold describing the result type.  May be used by the print processor
  # as a hint for printing the output.
  def result_type(type)
    @result_type=type
  end

  def execute(parameters)
    def set_result_message(msg)
      @response.message=msg
    end

    def set_result_type(type)
      @response.type=type
    end

#    def output(params)
#      @response.data<<params
#    end

    raise LoopError.new("Loop detected, Command.execute called more than 3 times") if caller.grep(caller[0]).length>3
    @response=Response.new
    @response.type=@result_type if !@result_type.nil?

    puts @depreciated if !@depreciated.nil?
    if !@flags.nil? && @flags[:login_required] && !server.connected?
      raise LoginRequired.new("\"#{@command_name}\" requires an active login")
    end

    @response.data=@cmd_method.call(parameters)

    retval=@response  #ensure @result is empty for our next use
    @response=nil

    retval
  end

  private

  def parameter_error(msg)
    raise ParameterError.new(msg)
  end

  def server
    ZabbixServer.instance
  end

  def global_vars
    GlobalVars.instance
  end
end

class CommandList
  include ZDebug
  include Singleton

   class InvalidCommand < Exception
    def initialize(str)
      @str=str
    end

    def message
      "Unknown or Invalid Command: #{@str}"
    end
  end

  class Cmd
    attr_reader :command_obj, :parameters

    def initialize(command_obj,parameters)
      @command_obj=command_obj
      @parameters=parameters
    end
  end  #End Cmd sub class

  def initialize
    @cmd_tree={}
  end

  def insert(insert_path, cmd_obj)
    raise "Insert_path must be an array" if insert_path.class!=Array
    tree_node=@cmd_tree
    path_length=insert_path.length-1
    insert_path.each_index do |index|
      if tree_node[insert_path[index]].nil?
        if index<path_length
          tree_node[insert_path[index]]={}
          tree_node=tree_node[insert_path[index]]
        else
          tree_node[insert_path[index]]={:node=>cmd_obj}
        end
      else
        tree_node=tree_node[insert_path[index]]
      end
    end

    (0..(cmd_obj.alias_total-1)).each {|i|
      insert(cmd_obj.aliases[i],cmd_obj.generate_alias(i))} if cmd_obj.alias_total>0
  end

  def get(path)
    path=setup_path(path)

    cur_node=@cmd_tree
    count=0

    path.collect do |item|
      break if cur_node[item].nil?
      count+=1

      cur_node=cur_node[item]
    end

    cmd=cur_node.nil? ? nil : cur_node[:node]
  end

  def find_and_parse(str)

    tokens=Tokenizer.new(str)
    token_items=tokens.length

    cur_node=@cmd_tree
    pos=tokens.walk(0)

    while !tokens.end?(pos)
      item=tokens[pos].value
      break if cur_node[item].nil?
      cur_node=cur_node[item]
      pos=tokens.walk(pos+1)
    end

    #tokens.each do |item|
    #  if item.empty? || !item.scan(/^\s*$/).empty?
    #    count+=1
    #  else
    #    break if cur_node[item].nil?
    #    count+=1
    #    cur_node=cur_node[item]
    #  end
    #end

    raise InvalidCommand.new(str) if cur_node.nil? || !cur_node[:node]

    cmd=cur_node[:node]
    #params=str_array[count..str_array.length].join.strip

    debug(6,:msg=>"Tokens", :var=>tokens)
    debug(6,:msg=>"Pos", :var=>pos)
    debug(6,:msg=>"Parsed", :var=>tokens.parse)
    params = tokens.drop(pos+1).join

    debug(6,:msg=>"Parameters", :var=>params)

    Cmd.new(cmd,params)
  end

  def get_command_list(tree=nil)
    def get_subtree(tree)
      tmp=tree.dup
      path=nil
      if !tmp[:node].nil?
        path=tree[:node].path.join(" ")
        tmp.delete(:node)
      end
      tree=tmp

      if tree.empty?
        return path if !path.nil?
        return nil
      end
      results=tree.keys.sort.map {|key|
        get_subtree(tree[key])
      }
      [path,results]
    end

    get_subtree(@cmd_tree).flatten.compact.sort
  end

  private

  def setup_path(path)
    if path.class==Array
      path
    elsif path.class==String
      path.split2
    else
      raise "Path must be Array or string"
    end
  end
end

#Base module for instantiating Zabcon commands.
module ZabconCommand
  #Method used to add commands to the Zabcon command processor
  #path is the command path such as "get host group"
  #A block must also be passed, this block will be executed against the
  # Command object to to define the command and then inserted into the
  # global CommandList singleton.
  def self.add_command (path, &block)
    path=
        if path.class==Array
          path
        elsif path.class==String
          path.split2(:trim_empty=>true)
        else
          raise "Path must be Array or string"
        end
    cmd=Command.new(path)
    cmd.instance_eval(&block)
    raise "Help tag required for \"#{path.join(" ")}\", and must be of type symbol.  Use the symbol :none for no help" if cmd.help_tag.class!=Symbol
    CommandList.instance.insert(path,cmd)
  end

end

if __FILE__ == $0

end
