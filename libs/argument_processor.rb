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
#    args=args.strip  #remove preceding and trailing whitespace
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
