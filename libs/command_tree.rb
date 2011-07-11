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

require 'singleton'
require 'libs/zdebug'
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
    rescue ParameterError => e
      e.help_func=cmd_obj.command_obj.help_method
      raise e
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

  attr_reader :show_params, :results, :options

  def initialize(usr_str)
    @initial_string=usr_str
    @commands=[]
    @printing=true
    commandlist=CommandList.instance

    split_str=usr_str.split2(:split_char=>'=|\s', :include_split=>true)

    unravel=false  #remove any extra space before the first =
    split_str2=split_str.map {|item|
      if unravel
        item
      elsif item=="="
        unravel=true
        item
      elsif item.empty?
        nil
      elsif item.scan(/\s/).empty?
        item
      else
        nil
      end
    }.delete_if {|i| i.nil?}

    if !split_str2[1].nil? && split_str2[1]=='='
      split_str=split_str2  #use the trimmed version
      var_name=split_str[0].strip
      raise ParseError.new("Variable names cannot contain spaces or invalid characters \"#{var_name}\"",:retry=>true) if !var_name.scan(/[^\w]/).empty?

      debug(5,var_name,"Creating Variable assignment")
      add(ZabconExecuteVariable.new(var_name))

      usr_str=split_str[2..split_str.length-1].join.strip
      debug(5,str,"Continuging to parse with")
    end

    cmd=commandlist.find_and_parse(usr_str)
    add(ZabconExecuteCommand.new(cmd))

  end

  def print?
    @printing==true   #Ensure we get a boolean ;-)
  end

  def add(obj)
    raise "Expected ZabconExecuteCommand Class" if obj.class!=ZabconExecuteCommand
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

class Command
  attr_reader :str, :aliases, :argument_processor, :flags, :valid_args
  attr_reader :help_tag

  include ArgumentProcessor

  class Arguments
    attr_accessor :cmd_params, :show_params

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
  end

  class LoginRequired < Exception
  end

  class ParameterError < Exception
  end

  class ArgumentError < Exception
  end

  def initialize(path)
    raise "Path must be an array" if path.class!=Array
    @path=path
    @cmd_method=nil
    @valid_args=[]
    @aliases=[]
    @flags={}

    #TODO Can the argument processor stuff be cleaned up?
    @argument_processor=method(:default_processor)
    @help_tag=nil
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

  def add_alias(name)
    @aliases<<name.split2
  end

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

  #accepts an array of valid arguments
  def set_valid_args(args)
    @valid_args=args
  end

  def default_show(cols)
    raise "Cols must be an array" if cols.class!=Array
    @flags[:default_cols]=cols
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

  #TODO Complete type casting section and add error checking
  def set_flag(flag)
    case flag.class.to_s
      when "Symbol"
        flag={flag=>true}
    end

    @flags.merge!(flag)
  end

  def call_arg_processor(parameters)
    result=@argument_processor.call(parameters,@valid_args,@flags)
    return result if result.class==Arguments
    if result.class!=String && result.class!=Hash && result.class!=Array
      raise ("Arugment processor for \"#{command_name}\" returned invalid parameters: class: #{result.class}, #{result}")
    else
      Arguments.new(result,@flags)
    end
  end

  def execute(parameters)
    if !@flags.nil? && @flags[:login_required] && !server.connected?
      raise LoginRequired.new("\"#{@command_name}\" requires an active login")
    end

    @cmd_method.call(parameters)
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
    str_array=str.split2(:include_split=>true)
    str_items=str_array.length

    cur_node=@cmd_tree
    count=0

    str_array.each do |item|
      if item.empty? || !item.scan(/^\s*$/).empty?
        count+=1
      else
        break if cur_node[item].nil?
        count+=1
        cur_node=cur_node[item]
      end
    end

    raise InvalidCommand.new(str) if cur_node.nil? || !cur_node[:node]

    cmd=cur_node[:node]
    params=str_array[count..str_array.length].join.strip

    Cmd.new(cmd,params)
  end

  def register(command_str, function)
    cmd=Command.new(command_str,function)
    insert(command_str.split2,cmd)
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

module ZabconCommand
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
