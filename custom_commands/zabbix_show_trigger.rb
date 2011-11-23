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

require "pp"
#Custom_command_show_trigger

ZabconCommand.add_command "zabbix show trigger" do
  set_method do |params|
    show_db_expression=params["show_db_expression"] || false
    params.delete("show_db_expression") if show_db_expression
    select_functions=params["select_functions"] || false
    params.merge!("output"=>"extend","select_functions"=>"extend")
    triggers=server.connection.trigger.get(params)
    triggers.each do |trigger|
      tr_expression=trigger["expression"]
      while tr_expression =~ /\{(\d*)\}/
        func_num =/\{(\d*)\}/.match($&)[1]
        func=trigger["functions"].select {|i|
          i["functionid"]==func_num
        }[0]
        item=server.connection.item.get("itemids"=>func["itemid"],"output"=>"extend")[0]
        host=server.connection.host.get("hostids"=>item["hostid"],"output"=>"extend")[0]
        func_text="{#{host["host"]}:#{item["key_"]}.#{func["function"]}(#{func["parameter"]})}"
        tr_expression=tr_expression.sub(/\{\d*\}/,func_text)
      end
      trigger["db_expression"]=trigger["expression"] if show_db_expression
      trigger["expression"]=tr_expression
      trigger.delete("functions") unless select_functions
    end
    p triggers
    triggers
  end

  default_show ["triggerid","expression","description","value","status"]
  set_valid_args 'triggerids', "select_functions", "show_db_expression", "nodeids",
      "groupids", "templateids", "hostids", "itemids", "applicationids", "functions",
      "inherited", "templated", "monitored", "active", "maintenance", "withUnacknowledgedEvents",
      "withAcknowledgedEvents", "withLastEventUnacknowledged", "skipDependent", "editable",
      "lastChangeSince", "lastChangeTill", "filter", "group", "host", "only_true", "min_severity",
      "search", "startSearch", "excludeSearch", "searchWildcardsEnabled", "output", "expandData",
      "expandDescription", "select_groups", "select_hosts", "select_items", "select_dependencies",
      "countOutput", "groupOutput", "preservekeys", "sortfield", "sortorder", "limit"
  set_help_tag :none
  set_flag :login_required
  set_flag :print_output
  result_type :triggers
end
