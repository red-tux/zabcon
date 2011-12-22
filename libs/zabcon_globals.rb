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

#------------------------------------------------------------------------------
#
# Class ZbxAP_ParameterError
#
# Exception class for parameter errors for Argument Processor calls.
#
#------------------------------------------------------------------------------

require 'zbxapi/zdebug'

require 'singleton'
require 'parseconfig'
require 'pp'

#This class is for containing responses from the Command tree
class Response

   class InvalidType < Exception
   end

   attr_accessor :data    #response data
   attr_accessor :message
   attr_reader :type

   def initialize(val=nil, data_class=nil)
     data=val
     @type=nil
     @message=nil
   end

  def type=(type)
    raise InvalidType.new("Response.type must be a symbol") if type.class!=Symbol
    @type=type
  end
 end


# This class is for storing global variables.  This is accomplished by inheriting
# the singleton class.  To use a global variable it must be registered and then
# if some part of the program needs to be notified of a change a notifier can
# be registered for that variable.
class GlobalsBase
  include Singleton
  include ZDebug

  def initialize
    @hash={}
    @callbacks={}
  end

  # overload the assignment operator
  def []=(key,val)
    debug(9,:var=>[key,val],:msg=>"Entering []= (key,val)",:overload=>true)
    if val.nil?
      delete(key) if !@hash[key].nil?
    else
      if !@hash[key].nil? and (@hash[key].class==Fixnum or @hash[key].class==Bignum)
        @hash[key]=Integer(val)
      else
        @hash[key]=val
      end

      if !@callbacks[key].nil?
         @callbacks[key].each {|proc|
           proc.call(@hash[key])  #use the value stored in the hash should there have been a conversion
         }
      end
    end
  end

  # overload the array operator
  def [](key)
    debug(9,:var=>key,:msg=>"Entering [] (key)",:overload=>true)
    if @hash[key].nil?
      return nil
    else
      return @hash[key]
    end
  end

  def select_keys(keys)
    @hash.select_keys(keys)
  end

  def delete(key)
    @hash.delete(key)
  end

  def empty?
    return @hash.empty?
  end

  def each
    @hash.each {|k,v| yield k,v }
  end

  # Register a function to be called when the value of key changes.
  def register_notifier(key,proc)
    debug(9,:var=>[key,proc],:msg=>"Entering register_notifier (key,proc)")
    if @callbacks[key].nil?
      @callbacks[key]=[proc]
    else
      @callbacks[key]<<proc
    end
  end
end

class GlobalVars < GlobalsBase

  def initialize
    super()
  end

end

class ServerCredentials < GlobalsBase
  def initialize
    super()
  end
end

class EnvVars < GlobalsBase
  def initialize
    super()
  end
end
