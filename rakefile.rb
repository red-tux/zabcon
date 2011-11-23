#License:: GPL 2.0  http://www.gnu.org/licenses/gpl-2.0.html
#Copyright:: Copyright (C) 2009,2010 Andrew Nelson nelsonab(at)red-tux(dot)net
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
# $Id: $
# $Revision: $
##########################################

require 'rubygems'
require 'rubygems/package_task'
require 'rake'
require 'rake/rdoctask'

$rev = %x[svn -R info * 2>&1 | grep Revis | cut -f2 -d" "|sort -ur|head -1].chop.to_i

spec = Gem::Specification.new do |s|
  s.name = %q{zabcon}
  s.rubyforge_project = "zabcon"
  s.version = "0.0.#{$rev}"
  s.authors = ["A. Nelson"]
  s.email = %q{nelsonab@red-tux.net}
  s.summary = %q{Zabcon command line interface for Zabbix}
  s.homepage = %q{http://trac.red-tux.net/}
  s.description = %q{Zabcon is a command line interface for Zabbix written in Ruby}
  s.licenses = "GPL 2.0"
  s.requirements = "Requires zbxapi, parseconfig and highline"
  s.add_dependency("zbxapi", '>=0.1.324')
  s.add_dependency("parseconfig")
  s.add_dependency("highline")
  s.required_ruby_version = '>=1.8.6'
  s.require_paths =["."]
  s.files =
    ["zabcon.rb", "zabcon.conf.default", "README",
     "revision_information",
     "libs/argument_processor.rb", "libs/revision.rb",
     "libs/command_help.rb", "libs/command_tree.rb",
     "libs/help.xml", "libs/input.rb", "libs/lexer.rb",
     "libs/printer.rb", "libs/zabcon_commands.rb",
     "libs/zabcon_core.rb","libs/zabcon_exceptions.rb",
     "libs/zabcon_globals.rb", "libs/zabbix_server.rb",
     "libs/utility_items.rb"]
  s.bindir = "."
  s.executables << "zabcon.rb"
  s.default_executable="zabcon"
end


desc "Update the revision to the lastest svn number"
task :update_revision do
  open("libs/revision.rb", "w") do |outfile|
    outfile.puts "REVISION=#{$rev}"
  end
end

task :checkout_zbxapi do
  %x[svn co http://svn.red-tux.net/trunk/ruby/api zbxapi_tmp] unless ENV["SKIP_CHECKOUT"]
end

desc "Cleanup"
task :cleanup do
  %x[rm -rf zbxapi_tmp]
end

desc "Build dependencies to test Zabcon"
task :test => [:update_revision, :checkout_zbxapi]

Gem::PackageTask.new(spec) do |pkg|
  pkg.package_dir = "gems"
#  pkg.version = "0.1.#{$rev}"
end

Rake::RDocTask.new do |rd|
  #rd.main = "README.rdoc"
  rd.rdoc_files.include("*.rb", "libs/*.rb")
end

task :default => [:update_revision, :package]

