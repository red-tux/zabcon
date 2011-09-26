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
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.                              d

##########################################
# Subversion information
# $Id$
# $Revision$
##########################################

#$: << File.expand_path(File.join(File.dirname(__FILE__), '..'))

#import variables which describe our local test environment
#require "ts_local_vars"

require 'rubygems'
require "test/unit"
require 'tests/test_utilities'
require 'zbxapi/zdebug'
require "libs/lexer"

class TC_Test_00_Lexerr < Test::Unit::TestCase
  include ZDebug

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    set_debug_level(0)
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown

  end

  def test_00_simple_string_1
    result=nil

    test_str="word1 word2,word3 , d , e"
    out = capture_stdout do
      tokens=Tokenizer.new(test_str)
      result=tokens.parse
    end
    assert_equal(["word1", ["word2", "word3", "d", "e"]],result)
  end

  def test_00_simple_string_2
    result=nil

    test_str="  test   a=1, bla {b={c=2}}"
    out = capture_stdout do
      tokens=Tokenizer.new(test_str)
      result=tokens.parse
    end
    assert_equal(["test", [{"a"=>1}, "bla", {"b"=>{"c"=>2}}]],result)
  end

  def test_00_simple_string_3
    result=nil

    test_str="word1 word2,word3 } , d , e"

    out = capture_stdout do
      result= assert_raise(Tokenizer::UnexpectedClose){
        tokens=Tokenizer.new(test_str)
        tokens.parse
      }
    end

    assert_equal(18,result.position,"Error was expected at the 18th character")
  end

  def test_00_simple_string_4
    result=nil

    test_str="  word1 word2,word3   , d , e,"

    out = capture_stdout do
      result= assert_raise(Tokenizer::InvalidCharacter){
        tokens=Tokenizer.new(test_str)
        tokens.parse
      }
    end

  end

  def test_05_string_1
    result=nil

    test_str="  test   a=1, bla {b={c=2}}"

    out = capture_stdout do
      tokens=Tokenizer.new(test_str)
      result=tokens.parse
    end

    assert_equal(["test", [{"a"=>1}, "bla", {"b"=>{"c"=>2}}]],result,out.string)
  end

  def test_05_escaped_string_1
    result=nil

    test_str="\\test \\\\test2"

    set_debug_level(8)
    out = capture_stdout do
      tokens=Tokenizer.new(test_str)
      result=tokens.parse
    end

    assert_equal(["test","\\test2"],result,out.string)
  end

  def test_05_escaped_string_2
    result=nil

    test_str="\\\\ \\ "

    set_debug_level(8)
    out = capture_stdout do
      tokens=Tokenizer.new(test_str)
      result=tokens.parse(:keep_escape=>true)
    end

    assert_equal(["\\\\ ","\\ "],result,out.string)
  end

  def test_05_escaped_string_3
    result=nil

    test_str=" \\"

    set_debug_level(8)
    out = capture_stdout do
      result= assert_raise(Tokenizer::EscapeEnd){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
      }
    end
  end

  def test_05_commented_string_1
    result=nil

    test_str="This is a test #comment bla bla bla"

    set_debug_level(8)
    out = capture_stdout do
#      result= assert_raise(Tokenizer::EscapeEnd){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
#      }
    end

    assert_equal(["This", "is", "a", "test"],result,out.string)
  end

  def test_05_commented_string_2
    result=nil

    test_str="1,2,3 #comment bla bla bla"

    set_debug_level(8)
    out = capture_stdout do
#      result= assert_raise(Tokenizer::EscapeEnd){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
#      }
    end

    assert_equal([1,2,3],result,out.string)

  end

  def test_05_commented_string_3
    result=nil

    test_str="1,2,3 { #comment bla bla bla"

    set_debug_level(8)
    out = capture_stdout do
      result= assert_raise(Tokenizer::InvalidCharacter){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
      }
    end

    assert_equal(8,result.position,out.string)

  end

  def test_05_hash_string_1
    result=nil

    test_str="1=2"

    set_debug_level(8)
    out = capture_stdout do
#      result= assert_raise(Tokenizer::InvalidCharacter){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
#      }
    end

    assert_equal([{1=>2}],result,out.string)

  end

  def test_05_hash_string_2
    result=nil

    test_str="1=2 2=3 4=5,6=7"

    set_debug_level(8)
    out = capture_stdout do
#      result= assert_raise(Tokenizer::InvalidCharacter){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
#      }
    end

    assert_equal([{1=>2}, {2=>3}, [{4=>5}, {6=>7}]],result,out.string)

  end

  def test_05_hash_string_3
    result=nil

    test_str="1= { 2= 3, 4=5,6=7}"

    set_debug_level(8)
    out = capture_stdout do
#      result= assert_raise(Tokenizer::InvalidCharacter){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
#      }
    end

    assert_equal([{1=>{6=>7, 2=>3, 4=>5}}],result,out.string)

  end

  def test_05_hash_string_4
    result=nil

    test_str="1={ 2=3 4=5,6=7}"

    set_debug_level(8)
    out = capture_stdout do
      result= assert_raise(Tokenizer::InvalidCharacter){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
      }
    end

    assert_equal(8,result.position,out.string)
    assert_equal(4,result.invalid_char,out.string)

  end


  def test_05_hash_string_5
    result=nil

    test_str="1={2=3, { 4=5,6=7}"

    set_debug_level(8)
    out = capture_stdout do
      result= assert_raise(Tokenizer::InvalidCharacter){
        tokens=Tokenizer.new(test_str)
        result=tokens.parse(:keep_escape=>true)
      }
    end

    assert_equal(8,result.position,out.string)
    assert_equal("{",result.invalid_char,out.string)

  end

end