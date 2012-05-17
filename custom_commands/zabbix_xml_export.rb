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


require 'net/http'
require 'net/https'
require 'pp'

class ZabbixWebClient
  include ZDebug

  def initialize
    uri=URI.parse(ZabbixServer.instance.server_url)
    @server=ZabbixServer.instance.connection.get_http_obj

    @cookies="zbx_sessionid=#{ZabbixServer.instance.connection.auth}"
    @headers={'User-Agent'=>'Zbx Ruby CLI',
             'Cookie'=>@cookies}
    path="/zabbix/dashboard.php"

    data=get2(path)

    #Get an SID by pulling the dashboard.
    if (result=data.match(/sid=(.+)&/))
      @sid=result[1]
    else
      #TODO Integrate with Zabcon error classes
      raise "Unable to determine SID from Zabbix Server"
    end
  end

  def get2(path,headers={})
    headers=@headers.merge(headers)
    resp, data = @server.get2(path, headers)
    #check to see if there was an error
    msg=nil
    case
      when resp.code.to_i==301
        msg="Server returned HTTP 301, redirection to: #{resp['location']}"
      when resp.code.to_i==500
        msg="Zabbix returned an internal error.  Check parameters before trying again"
      when (resp.code.to_i<200 || resp.code.to_i>299)
        msg="Zabbix server returned HTTP #{resp.code.to_i}.  \"#{resp.msg}\"\n"
        msg+="Path: #{path}"
      when resp.response.main_type!="text"
        msg="Response type was not text.  Type was: #{resp.response.main_type}."
    end
    raise Command::NonFatalError.new(msg) if msg
    debug(6, :var=>resp.response.to_hash, :msg=>"Response Hash")
    debug(6, :var=>data.length, :msg=>"Returned data size")
    data
  end

  #Export function for 1.8
  def export18(hosts,filename)
    uri=hosts.map {|hostid| "hosts[#{hostid}]=#{hostid}"}.join("&")
    uri+="&go=export&goButton=Go+(#{hosts.length})"
    uri=URI.escape(uri)
    path="/zabbix/hosts.php?sid=#{@sid}&#{uri}"
    data=get2(path)
    open(filename, "wb").write(data)
    puts "Wrote #{File.stat(filename).size} bytes to \"#{filename}\""
  end

end

ZabconCommand.add_command "xml export" do
  set_method do |params|

    raise "parameter 'file=' missing" if params["file"].nil?
    filename=params["file"]
    params.delete("file")

    hostids=params.keys.map {|i|
      i.to_i if i.is_a?(String)
      }.delete_if{|i|!i.is_a?(Integer) || i==0}

    puts "Checking host ids"
    ok=true
    hostids.each do |id|
      if server.connection.host.get({"hostids"=>[id]}).empty?
        puts "Unknown id: #{id}"
        ok=false
      end
    end

    raise "Found unknown host ids" if !ok

    zbxweb=ZabbixWebClient.new
    if server.version.to_f<1.4
      zbxweb.export18(hostids,filename)
    else
      puts "Export implemented for 1.8.x only."
    end

  end

  set_help_tag :none
  set_flag :login_required
end
