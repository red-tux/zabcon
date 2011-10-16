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

#Custom_command_get_graph
#This file contains the custom command "zabbix get graph" for Zabcon
#This is designed to be a drop in for Zabcon.  To use this file
#copy it to your system (home directory recommended unless another directory is preferred)
#then modify your zabcon.conf file and set the option custom_commands
#to point to the path for this file.  If no path is defined zabcon will
#use the current directory used to execute Zabcon as the path to begin
#searching.

#To ensure this has loaded type the following in zabcon:
# help commands
#then look for "zabcon get graph" near the bottom of the list.

#This command takes multiple options
#itemid, graphid, start, end, filename, timefmt, width
#itemid or graphid is required, but not both
#start and end can use the following syntax:
# now-1h  which results in the current time minus one hour
#The units are not required, and defaults to one hour.
#h,H (Hour, default if no units given)
#m,M (Minutes)
#d,D (Days
#o,O (mOnths)

require 'net/http'
require 'net/https'
require 'time'
require 'uri'

def calctime(start,operator,amount,unit)
  #be sure start does not have seconds or a timezone
  #plus set up for later just in case
  year=start.year
  month=start.month-1  #adjust to start at 0 not 1
  day=start.day-1  #adjust to start at 0 not 1
  hour=start.hour
  minute=start.min

  start=DateTime.new(year,month+1,day+1,hour,minute)

  return start if operator.nil?  #return the reprocessed date if there's no more conversion needed

  days_month=[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  days_month[1]=29 if Date.gregorian_leap?(start.year)

  #set up op to be the symbol of operator for dynamic method calling later
  op=operator.intern
  plus=:+

  amount=amount.to_i

  unit= unit || "h"
  case unit
    when "o","O"
      month=month.method(op).call(amount)
    when "d","D"
      day=day.method(op).call(amount)
    when "h","H"
      hour=hour.method(op).call(amount)
    when "m","M"
      minute=minute.method(op).call(amount)
  end

  if (minute<0) || (minute>59)
    hours=1+(minute.abs/60).floor
    hour= hour.method(op).call(hours)
    minute=op==plus ? minute%60 : 60-(minute.abs%60)
  end

  if (hour<0) || (hour>23)
    days=1+(hour.abs/24).floor
    day=day.method(op).call(days)
    hour=op==plus ? hour%24 : 24-(hour.abs%24)
  end

  #Calculate to see if we're past the end of the month
  #day is indexed to 0 not one so adjust as needed
  #month is also indexed to 0
  if (day<0) || (day>(days_month[month]-1))
    date=start.method(op).call(days.abs)
    day=date.day-1  #readjust to index from 0
    month=date.month-1  #readjust to index from 0
    year=date.year
  end

  if (month<0) || (month>11)
    years=1+(month.abs/12).floor
    year=year.method(op).call(years)
    month=op==plus ? month%12 : 12-(month.abs%12)
  end

  #return the new time, readjust indexes for return as needed
  DateTime.new(year,month+1,day+1,hour,minute)
end

ZabconCommand.add_command "zabbix get graph" do
  set_method do |params|
    start_t=params["start"] || "now-1h"
    end_t=params["end"] || "now"

    #Process the start time
    if params["timefmt"]
      time_start=DateTime.strptime(params["start"], params["timefmt"])
    else
      if params["start"]
        t_calc_regex=/(now)(?:([-\+])(\d*)([mMhHdDoO])?)?/
        match = start_t.match(t_calc_regex)
        case match[1]
          when "now"
            time_start=DateTime.now
          else
            Command::NonFatalError.new("Invalid start time keyword")
        end
        time_start=calctime(time_start, match[2], match[3], match[4])
      end

      if params["end"]
        match = end_t.match(t_calc_regex)
        case match[1]
          when "now"
            time_end=DateTime.now
          else
            Command::NonFatalError.new("Invalid end time keyword")
        end
        time_end=calctime(time_end, match[2], match[3], match[4])
      end
    end

    #ensure time_start and time_end are set
    time_start=calctime(DateTime.now, "-", 1, nil) if time_start.nil?
    time_end=calctime(DateTime.now, nil, nil, nil) if time_end.nil?

    #calculate the number of seconds between start/end
    time_end_s = Time.parse(time_end.to_s).to_i
    time_start_s = Time.parse(time_start.to_s).to_i
    period=time_end_s-time_start_s
    raise Command::NonFatalError.new("Time period cannot be 0 or negative (start must be before end)") if period<1

    uri=URI.parse(server.server_url)
    zbx_front = Net::HTTP.new(uri.host, uri.port)
    zbx_front.use_ssl=true if uri.class==URI::HTTPS

    cookies="zbx_sessionid=#{server.connection.auth}"
    headers={'User-Agent'=>'Zbx Ruby CLI',
             'Cookie'=>cookies}

    path=nil
    if params["graphid"]
      path="/char2.php?graphid=#{params["graphid"]}"
    else
      path="/chart.php?itemid=#{params["itemid"]}"
    end
    path+="&stime=#{time_start_s}"
    path+="&period=#{period}"
    path+="&width=#{params["width"]}" if params["width"]
    uri.merge!(path)
    debug(6, :var=>uri.to_s, :msg=>"Request URL")
    resp, data = zbx_front.get2(uri.to_s, headers)

    #check to see if there was an error
    msg=nil
    case
      when resp.code.to_i==301
        msg="Server returned HTTP 301, redirection to: #{resp['location']}"
      when resp.code.to_i==500
        msg="Zabbix returned an internal error.  Check parameters before trying again"
      when (resp.code.to_i<200 || resp.code.to_i>299)
        msg="Zabbix server returned HTTP #{resp.code.to_i}.  \"#{resp.msg}\"\n"
        msg+="Url: #{uri.to_s}"
      when resp.response.main_type!="image"
        msg="Response type was not an image.  Type was: #{resp.response.main_type}."
    end
    raise Command::NonFatalError.new(msg) if msg

    debug(6, :var=>resp.response.to_hash, :msg=>"Response Hash")
    debug(6, :var=>data.length, :msg=>"Returned data size")
    if params["filename"]
      filename="#{params["filename"]}.#{resp.response.sub_type}"
    else
      filename="zabcon_get_graph.#{resp.response.sub_type}"
    end
    open(filename, "wb").write(data)
    puts "Wrote #{File.stat(filename).size} bytes to \"#{filename}\""
  end

  set_help_tag :none
  set_flag :login_required
  set_valid_args 'itemid', 'graphid', 'start', 'end', 'filename', 'timefmt', 'width'
  required_args ["itemid", "graphid"]
end
