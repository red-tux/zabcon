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

require 'zbxapi'
require 'libs/zdebug'
require 'libs/zabcon_globals'
require 'libs/command_tree'

class ZabbixServer_overload < ZabbixAPI
  alias zbxapi_initialize initialize
  alias zbxapi_do_request do_request

  def initialize(url,debug_level=0)
    @env = env
    zbxapi_initialize(url,debug_level)
  end

  #truncate_length is set to the symbol :not_used as do_request is passed a different variable
  def do_request(json_obj,truncate_length=:not_used)
    zbxapi_do_request(json_obj,@env["truncate_length"])
  end
end

class ZabbixServer

  include Singleton
  include ZDebug

  class ConnectionProblem < Exception
    def initialize(msg)
      @msg=msg
    end

    def message
      "There was a problem connecting to the Zabbix server: #{@msg}"
    end
  end

  attr_accessor :server_url, :username, :password
  attr_reader :version, :connected, :connection

  def initialize
    @server_url=nil
    @username=nil
    @password=nil
    @connected=false
    @version=nil
    @connection=nil
  end

  #login
  # Perform the actual login to the Zabbix server
  # If the object variables url, username, and password have not been
  # set previously, an attempt will be made to use the global environment
  # variables.  If that does not work an exception will be raised.
  def login
    @server_url = @server_url.nil? ? env["server"] : @server_url
    @username = @username.nil? ? env["username"] : @username
    @password = @password.nil? ? env["password"] : @password

    error_msg=[]
    error_msg<<"Url not set" if @server_url.nil?
    error_msg<<"Username not set" if @username.nil?
    error_msg<<"Password not set" if @password.nil?

    raise ConnectionProblem.new(error_msg.join(", ")) if !error_msg.empty?

    @connection = ZabbixServer_overload.new(@server_url,env["debug"])
    @connection.login(@username,@password)
    @connected=true
    GlobalVars.instance["auth"]=@connection.auth
    @version=@connection.API_version
    puts "#{@server_url} connected"  if env["echo"]
    puts "API Version: #{@version}"  if env["echo"]

  end

  def logout
    begin
      @connection.logout
    rescue ZbxAPI_GeneralError => e
      #if it's -32400, it's probably because the function does not exist.
      raise e if e.message["code"]!=-32400
    ensure
      @connection=nil
      @connected=false
      @version=nil
      GlobalVars.instance.delete("auth")
      puts "Logout complete from #{@server_url}" if env["echo"]
    end
  end

  def loggedin?
    @connected
  end

  #TODO come back and finish the class to have automated
  #timeout of the connection, and improve the usability of
  #this function which should tell you if you have a valid
  #connection or not, which includes timeout and login.
  def connected?
    @connected
  end

  def version
    @connection.API_version
  end

  def reconnect
    @connection.login(@user,@password)
  end

#  def getuser(parameters)
#    debug(6,parameters)
#
#    result=@connection.user.get(parameters)
#    {:class=>:user, :result=>result}
#  end
#
#  def gethost(parameters)
#    debug(6,parameters)
#
#    result=@connection.host.get(parameters)
#    {:class=>:host, :result=>result}
#  end

#  def addhost(parameters)
#    debug(6,parameters)
#    result=@connection.host.create(parameters)
#    {:class=>:host, :message=>"The following host was created: #{result['hostids']}", :result=>result}
#  end

#  def deletehost(parameters)
#    debug(6,parameters)
#    result=@connection.host.delete(parameters)
#    {:class=>:host, :message=>"The following host(s) was/were deleted: #{result['hostids']}", :result=>result}
#  end

#  def getitem(parameters)
#    debug(6,parameters)
#
#    result=@connection.item.get(parameters)
#    {:class=>:item, :result=>result}
#  end

#  def additem(parameters)
#    debug(6,parameters)
#    {:class=>:item, :result=>@connection.item.create(parameters)}
#  end

#  def deleteitem(parameters)
#    debug(6,parameters)
#    {:class=>:item, :result=>@connection.item.delete(parameters)}
#  end

#  def adduser(parameters)
#    debug(6,parameters)
#    begin
#      uid=@connection.user.create(parameters)
#      puts "Created userid: #{uid["userids"]}"
#    rescue ZbxAPI_ParameterError => e
#      puts "Add user failed, error: #{e.message}"
#    end
#  end

#  def deleteuser(parameter)
#    debug(6,parameter)
#    id=0  #id to delete
##    if parameters.nil? then
##      puts "User id required"
##      return
##    end
#
#    if !parameter["name"].nil?
#      users=@connection.user.get({"pattern"=>parameter["name"], "extendoutput"=>true})
#      users.each { |user| id=user["userid"] if user["alias"]==parameter }
#    else
#      id=parameter["id"]
#    end
#    result=@connection.user.delete(id)
#    if !result.empty?
#      puts "Deleted user id #{result["userids"]}"
#    else
#      puts "Error deleting #{parameter.to_a[0][1]}"
#    end
#  end

#  def updateuser(parameters)
#    debug(6,parameters)
#    valid_parameters=['userid','name', 'surname', 'alias', 'passwd', 'url', 'autologin',
#                      'autologout', 'lang', 'theme', 'refresh', 'rows_per_page', 'type',]
#    if parameters.nil? or parameters["userid"].nil? then
#      puts "Edit User requires arguments, valid fields are:"
#      puts "name, surname, alias, passwd, url, autologin, autologout, lang, theme, refresh"
#      puts "rows_per_page, type"
#      puts "userid is a required field"
#      puts "example:  edit user userid=<id> name=someone alias=username passwd=pass autologout=0"
#      return false
#    else
#      p_keys = parameters.keys
#
#      valid_parameters.each {|key| p_keys.delete(key)}
#      if !p_keys.empty? then
#        puts "Invalid items"
#        p p_keys
#        return false
#      elsif parameters["userid"].nil?
#        puts "Missing required userid statement."
#      end
#      p @connection.user.update([parameters])  #TODO: remove print statement or comment if needed
#    end
#  end

  def addusermedia(parameters)
    debug(6,:var=>parameters)
    valid_parameters=["userid", "mediatypeid", "sendto", "severity", "active", "period"]

    if parameters.nil? then
      puts "add usermedia requires arguments, valid fields are:"
      puts "userid, mediatypeid, sendto, severity, active, period"
      puts "example:  add usermedia userid=<id> mediatypeid=1 sendto=myemail@address.com severity=63 active=1 period=\"\""
    else

      p_keys = parameters.keys

      valid_parameters.each {|key| p_keys.delete(key)}
      if !p_keys.empty? then
        puts "Invalid items"
        p p_keys
        return false
      elsif parameters["userid"].nil?
        puts "Missing required userid statement."
      end
      begin
        @connection.user.addmedia(parameters)
      rescue ZbxAPI_ParameterError => e
        puts e.message
      end
    end

  end

#  def addhostgroup(parameters)
#    debug(6,parameters)
#    result = @connection.hostgroup.create(parameters)
#    {:class=>:hostgroup, :result=>result}
#  end

#  def gethostgroup(parameters)
#    debug(6,parameters)
#
#    result=@connection.hostgroup.get(parameters)
#    {:class=>:hostgroup, :result=>result}
#  end

  def gethostgroupid(parameters)
    debug(6,:var=>parameters)
    result = @connection.hostgroup.getObjects(parameters)
    {:class=>:hostgroupid, :result=>result}
  end

#  def getapp(parameters)
#    debug(6,parameters)
#
#    result=@connection.application.get(parameters)
#    {:class=>:application, :result=>result}
#  end
#
#  def addapp(parameters)
#    debug(6,parameters)
#    result=@connection.application.create(parameters)
#    {:class=>:application, :result=>result}
#  end

  def getappid(parameters)
    debug(6,:var=>parameters)
    result=@connection.application.getid(parameters)
    {:class=>:application, :result=>result}
  end

  def gettrigger(parameters)
    debug(6,:var=>parameters)
    result=@connection.trigger.get(parameters)
    {:class=>:trigger, :result=>result}
  end

#  # addtrigger( { trigger1, trigger2, triggern } )
#  # Only expression and description are mandatory.
#  # { { expression, description, type, priority, status, comments, url }, { ...} }
#  def addtrigger(parameters)
#    debug(6,parameters)
#    result=@connection.trigger.create(parameters)
#    {:class=>:trigger, :result=>result}
#  end

  def addlink(parameters)
    debug(6,:var=>parameters)
    result=@connection.sysmap.addlink(parameters)
    {:class=>:map, :result=>result}
  end

  def addsysmap(parameters)
    debug(6,:var=>parameters)
    result=@connection.sysmap.create(parameters)
    {:class=>:map, :result=>result}
  end

  def addelementtosysmap(parameters)
    debug(6,:var=>parameters)
    result=@connection.sysmap.addelement(parameters)
    {:class=>:map, :result=>result}
  end

  def getseid(parameters)
    debug(6,:var=>parameters)
    result=@connection.sysmap.getseid(parameters)
    {:class=>:map, :result=>result}
  end

  def addlinktrigger(parameters)
    debug(6,:var=>parameters)
    result=@connection.sysmap.addlinktrigger(parameters)
    {:class=>:map, :result=>result}
  end

#  def raw_api(parameters)
#    debug(6,parameters)
#    result=@connection.raw_api(parameters[:method],parameters[:params])
#    {:class=>:raw, :result=>result}
#  end

#  def raw_json(parameters)
#    debug(6,parameters)
#    begin
#      result=@connection.do_request(parameters)
#      {:class=>:raw, :result=>result["result"]}
#    rescue ZbxAPI_GeneralError => e
#      puts "An error was received from the Zabbix server"
#      if e.message.class==Hash
#        puts "Error code: #{e.message["code"]}"
#        puts "Error message: #{e.message["message"]}"
#        puts "Error data: #{e.message["data"]}"
#      end
#      puts "Original text:"
#      puts parameters
#      puts
#      return {:class=>:raw, :result=>nil}
#    end
#  end

end

##############################################
# Unit test
##############################################

if __FILE__ == $0
end
