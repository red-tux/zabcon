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
# $Id$
# $Revision$
##########################################

require "libs/zdebug"

Object.class_eval do
  def env
    EnvVars.instance
  end
end


String.class_eval do
# String::split2(*options)
# Valid options, and ther defaults:
#  :splitchar = '\s'
#    pivot string or regex
#  :include_split = false
#  :trim_empty = true
#    trim_empty will remove empty and whitespace characters by default
#    if include_split is true whitespace characters (but not empty) will
#    be included if the splitchar is a whitespace character (default)
# This is a special split routine which will split str using splitchar as a split point.
# If items are within quotes or brackets they will not be split even when splitchar is
# found within those quotes or brackets.
  def split2(*options)
    defaults={:split_char=>'\s', :include_split=>false, :trim_empty=>true}

    options=
        if options.empty?
          defaults
        else
          raise "split2 requires parameters to be in hash form" if options[0].class!=Hash
          unknown_keys=options[0].keys-defaults.keys

          raise "Unknown keys: #{unknown_keys.join(", ")}" if !unknown_keys.empty?
          defaults.merge(options[0])
        end

    splitchar=options[:split_char]
    include_split=options[:include_split]
    trim_empty=options[:trim_empty]
    str=self
    quote_chars=["\"", "'"]
    left=["(", "{", "["]
    right=[")", "}", "]"]
    quote_regex=Regexp.escape(quote_chars.to_s)
    left_regex=Regexp.escape(left.to_s)
    right_regex=Regexp.escape(right.to_s)
    splitchar_regex= Regexp.new(/#{splitchar}/)
    stack=[]
    splits=[]
    result=[]
    s=StringScanner.new(str)
    #set up our regex for scanning.  We scan for brackets, quotes and escaped characters
    char_class=Regexp.new("[\\\\#{quote_regex}#{left_regex}#{right_regex}#{splitchar}]")
    while !s.eos?
      s.scan_until(char_class)
      break if !s.matched?  # break out if nothing matched
      ch=str[s.pos-1].chr
      case ch
        when "\\"  #hande an escaped character by moving the pointer up one
          s.getch
        when /[#{quote_regex}]/  #handle a quoted section
          raise "Unbalanced String: #{str}" if (!stack.index(ch).nil? && stack.index(ch)!=(stack.length-1))
          if stack.index(ch)==nil
            stack<<ch
          else
            stack.pop
          end
        when /[#{left_regex}]/  #open bracket found
          stack<<left.index(ch)
        when /[#{right_regex}]/  #close bracket found
          raise "Unbalanced String: #{str}" if ch!=right[stack.last]
          stack.pop
        when /#{splitchar_regex}/  #pivot character found
          splits<<s.pos-1 if stack.empty?
      end
    end

    raise "Unbalanced String: #{str}" if !stack.empty?
    splits<<str.length

    pos=0
    while !splits.empty?
      split_pos=splits.first
      splits.delete(splits.first)
      result<<str[pos..split_pos-1] if split_pos>0
      result<<str[split_pos].chr if !str[split_pos].nil? && include_split
      pos=split_pos+1
    end

      result=result.delete_if {|item|
        if include_split
          #delete the line if nil or empty or the current item is not the splitchar and not full of whitespace
          item.nil? || item.empty? || (item.scan(/^#{splitchar}$/).empty? && !item.scan(/^\s*$/).empty?)
        else
          item.nil? || item.empty? || !item.scan(/^\s*$/).empty?
        end
      } if trim_empty

    result
  end

  def strip_comments
    splits = self.split2(:split_char=>'#', :include_split=>true)
    if !(index=splits.index('#')).nil?
      if index>0
        splits=splits[0..index-1]
      else
        splits=[]
      end
    end
    splits.join.strip
  end

end # end String.class_eval
