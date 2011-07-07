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

require 'libs/zdebug'
require 'libs/zabcon_exceptions'
require 'libs/zabcon_globals'
require 'libs/argument_processor'

class ZabconCommandBase
  include ZDebug

  attr_reader :results

  def execute
    raise "Unitialized base method"
  end

end

class ZabconCommand < ZabconCommandBase

  class NilCommand < Exception
  end

  class Exit < Exception
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


  attr_reader :show, :options, :help

  def initialize(commandproc=nil,apiparams=nil,showparams=nil,helpproc=nil,options=nil,orig_str=nil)
#    raise NilCommand if commandproc.nil?
    @proc=commandproc
    @args=apiparams
    @show=showparams
    @help=helpproc
    @options=options
    @orig_str=orig_str

    raise Help.new(self) if commandproc==:help

    @results=nil
  end

  def execute
    raise NilCommand if @proc.nil?
    raise Exit if @proc==:exit

    if @proc==:help
      @cmd_help.help(@commands,@orig_str)
    else
      @results=@proc.call(@args)
      @printing=@options.nil? ? true : @options[:suppress_printer].nil? ? true : false
    end
  end
end

class ZabconVariableCommand < ZabconCommandBase
  def initialize(var)
    @var=var
  end

  def assign(val)
    @results=val
    GlobalVars.instance[@var]=val
  end

end

class ZabconCommands

  attr_reader :show, :results, :options

  def initialize
    @commands=[]
    @printing=true
  end

  def add(obj)
    @commands<<obj
    if obj.class==ZabconCommand
      @printing=@printing & obj.options[:suppress_printer].nil? ? true : obj.options[:suppress_printer]==true
      @show=obj.show
      @options=obj.options
    end

  end

  def execute
    stack=[]
    ptr=0
    while ptr<@commands.length
      case @commands[ptr].class.to_s
        when "ZabconCommand"
          @commands[ptr].execute
          @results=@commands[ptr].results
        when "ZabconVariableCommand"
          stack<<ptr
      end
      ptr+=1
    end

    while !stack.empty?
      ptr=stack.pop
      @commands[ptr].assign(@results)
    end
  end

  def printing?
    @printing
  end
end

class Parser

  include ZDebug

  attr_reader :commands

  def initialize(default_argument_processor)
    @commands=NewCommandTree.new
    @default_argument_processor=default_argument_processor
  end

  def search(str)
    debug(7,str,"Searching")

    str=str.strip_comments


#    cmd_node=@commands.search(nodes)  # a side effect of the function is that it also manipulates nodes
     cmd_node=@commands.get_command(str)
    debug(7,cmd_node,"search result")
    return cmd_node[:command],cmd_node[:parameters]

  end


  # Returns an object of type ZabconCommands

  #Returns nil if the command is incomplete or unknown
  # If the command is known the associated argument processor is also called and it's results are returned as part
  # of the return hash
  # the return hash consists of:
  # :proc - the name of the procedure which will execute the associated command
  # :api_params - parameters to pass to the API call
  # :show_params - parameters to pass to the print routines
  # :helpproc - help procedure associated with the command
  # The argument processor function is passed a string of the arguments after the command, along with the
  # array of valid arguments and the help function associated with the command.
  # If the argument processor has an error it should call the help function and return nil.  In which case this function
  # will return nil
  #
  #TODO this function needs to move away from using so many hashes.
  def parse(str,user_vars=nil)
    debug(7,str,"Parsing")

    debug(7,user_vars,"User Variables")

    result_cmd=ZabconCommands.new

    split_str=str.split2('=|\s',true)

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
      varcmd=ZabconVariableCommand.new(var_name)
      result_cmd.add(varcmd)
      str=split_str[2..split_str.length-1].join.strip
      debug(5,str,"Continuging to parse with")
    end

    result=@commands.get_command(str)

    cmd=result[:command]

    command=nil
    if cmd.nil? or cmd[:commandproc].nil? then
      raise ParseError.new("Parse error, incomplete/unknown command: #{str}",:retry=>true)
    elsif cmd[:commandproc]==:help then
      help_proc=lambda {
        cmd[:helpproc].call(self,str)
      }
      command=ZabconCommand.new(:help,nil,nil,help_proc,nil,nil)
    else
      # The call here to the argument process requires one argument as it's a lambda block which is setup when the
      # command node is created
      debug(6,result[:parameters],"calling argument processor")
      args=cmd[:argument_processor].call(result[:parameters],user_vars)
      debug(6,args,"received from argument processor")
      retval = args.nil? ? nil : {:proc=>cmd[:commandproc], :helpproc=>cmd[:helpproc], :options=>cmd[:options]}.merge(args)
      command=ZabconCommand.new(retval[:proc], retval[:api_params], retval[:show_params], retval[:helpproc], retval[:options], str)
    end
    result_cmd.add(command)
    result_cmd
  end

  def complete(str,loggedin=false)
    nodes = str.split
    cmd_node=@commands
    i=0
    while i<nodes.length
      tmp=cmd_node.search(nodes[i])
      break if tmp.nil?
      cmd_node=tmp
      i+=1
    end

    if cmd_node.commandproc.nil? then
      # roll up the list of available commands.
      commands = cmd_node.children.collect {|node| node.command}

      # don't include the current node if the command is empty
      if cmd_node.command!="" then commands += [cmd_node.command] end
      return commands
    else
      puts "complete"
      return nil
    end
  end

  def insert(insert_path,commandproc,arguments=[],helpproc=nil,argument_processor=nil,*options)
    debug(10,{"insert_path"=>insert_path, "commandproc"=>commandproc, "arguments"=> arguments, "helpproc"=>helpproc, "argument_processor"=>argument_processor, "options"=>options})
#   insert_path_arr=[""]+insert_path.split   # we must pre-load our array with a blank node at the front
#    p insert_path_arr

    # If the parameter "argument_processor" is nil use the default argument processor
    arg_processor = argument_processor.nil? ? @default_argument_processor : argument_processor
    @commands.insert(insert_path,commandproc,arguments,helpproc,arg_processor,options)
  end

end

#{"add"=>{:node=>proc, "host"=>{:node=>proc,"group"=>{:node=>proc}}},"delete"=>...}

class NewCommandTree
  include ZDebug

  def initialize
    @tree = {}
  end

  def insert(insert_path,commandproc,arguments,helpproc,argument_processor,options)
    tree_node=@tree
    path_length=insert_path.length-1
    insert_path.each_index do |index|
      if tree_node[insert_path[index]].nil?
        if index<path_length
          tree_node[insert_path[index]]={}
          tree_node=tree_node[insert_path[index]]
        else
          local_arg_processor=lambda do |params,user_vars|
  	        if argument_processor.nil?
	            nil
	          else
	            argument_processor.call(helpproc,arguments,params,user_vars,options)  # We pass the list of valid arguments to
	         end
          end
          if options.nil?
  	        local_options=nil
	        else
	          local_options = Hash[*options.collect { |v|
	            [v, true]
	          }.flatten]
	        end
          tree_node[insert_path[index]]={:node=>
            {:commandproc=>commandproc, :arguments=>arguments, :helpproc=>helpproc,
             :argument_processor=>local_arg_processor,:options=>local_options}}
        end
      else
        tree_node=tree_node[insert_path[index]]
      end
    end
  end

  #get_command(String)
  #returns a Hash with two items: :command and :parameters
  #:command is a hash denoting all of the components of a the command when it was inserted
  #:parameters is the remainder of the String passed in.
  #
  #example:
  #  get_command("get host show=all")
  #  {:command=>{hash created from insert}, :parameters=>"show=all"}
  #
  #  get_command("get host test           test2")
  #  {:command=>{hash created from insert}, :parameters=>"test           test2"
    def get_command(str)
    str_array=str.downcase.split  #ensure all comparisons are done in lower case
    str_items=str_array.length

    cur_node=@tree
    count=0

    str_array.collect do |item|
      break if cur_node[item].nil?
      count+=1

      cur_node=cur_node[item]
    end

    cmd= cur_node.nil? ? nil : cur_node[:node]

    #remove preceding items found so we can return the remainder
    #as the parameters
    count.times do |i|
      str=str.gsub(/^#{str_array[i]}/,"")
      str=str.gsub(/^\s*/,"")
    end

    {:command=>cmd,:parameters=>str}
  end

end
  def search(search_path)
      debug(10,search_path,"search_path")
    return retval if results.empty?  # no more children to search, return retval which may be self or nil, see logic above
        debug(10)

        return results[0].search(search_path)
        debug(10,"Not digging deeper")

        return self if search_path[0]==@command

      end

  def insert(insert_path,command,commandproc,arguments,helpproc,argument_processor,options)
      do_insert(insert_path,command,commandproc,arguments,helpproc,argument_processor,options,0)
      end

  # Insert path is the path to insert the item into the tree
  # Insert path is passed in as an array of names which associate with pre-existing nodes
  # The function will recursively insert the command and will remove the top of the input path stack at each level until it
  # finds the appropraite level.  If the appropriate level is never found an exception is raised.
  def do_insert(insert_path,command,commandproc,arguments,helpproc,argument_processor,options,depth)
    debug(11,{"insert_path"=>insert_path, "command"=>command, "commandproc"=>commandproc, "arguments"=> arguments,
      "helpproc"=>helpproc, "verify_func"=>argument_processor, "depth"=>depth})
    debug(11,@command,"self.command")
#    debug(11,@children.map {|child| child.command},"children")

    if insert_path[0]==@command then
      debug(11,"Found node")
      if insert_path.length==1 then
        debug(11,command,"inserting")
        @children << CommandTree.new(command,commandproc,depth+1,arguments,helpproc,argument_processor,options)
      else
        debug(11,"Not found walking tree")
        insert_path.shift
        if !@children.empty? then
          @children.each { |node| node.do_insert(insert_path,command,commandproc,arguments,helpproc,argument_processor,options,depth+1)}
        else
          raise(Command_Tree_Exception,"Unable to find insert point in Command Tree")
        end
      end
    end
  end


if __FILE__ == $0

  require 'pp'
  require 'argument_processor'

  arg_processor=ArgumentProcessor.new()
  commands=Parser.new(arg_processoor.method(:default))
  commands.set_debug_level(6)


  def test_parse(cmd)
    puts "\ntesting \"#{cmd}\""
    retval=commands.parse(cmd)
    puts "result:"
    return retval
  end
  commands.set_debug_level(0)
  commands.insert "", "help", lambda { puts "This  is a generic help stub" }
  puts
  commands.insert "", "get", nil
  puts
  commands.insert "get", "host", :gethost, {"show"=>{:type=>nil,:optional=>true}}
  commands.set_debug_level(0)
  puts
  commands.insert "get", "user", :getuser
  puts
  commands.insert "get user", "group", :getusergroup
  puts

  pp commands

  commands.set_debug_level(0)

  test_parse("get user")
  test_parse("get user show=all arg1 arg2")
  test_parse("get user show=\"id, one, two, three\" arg1 arg2")
  test_parse("get user group show=all arg1")
  test_parse("set value")
  test_parse("help")[:proc].call


  p commands.complete("hel")
  p commands.complete("help")
  p commands.complete("get user all")

end
