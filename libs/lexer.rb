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

#--
##########################################
# Subversion information
# $Id$
# $Revision$
##########################################
#++

#The Lexr class is a fork from Michael Baldry's gem, Lexr
#The origional source for his work can be found here:
# https://github.com/michaelbaldry/lexr

require "libs/zdebug"

#This is a wrapper class for creating a generalized lexer.
class Lexr

  class NoLexerError < RuntimeError
  end

	def self.setup(&block)
		dsl = Lexr::Dsl.new
		block.arity == 1 ? block[dsl] : dsl.instance_eval(&block)
		dsl
	end

	def initialize(text, rules, default_rule, counter)
		@text, @rules, @default_rule = text, rules, default_rule
		@current = nil
		@position = 0
    @counter=counter
  end

  def parse
    retval=[]
    until self.end?
      retval << self.next
    end
    retval
  end

	def next
		return @current = Lexr::Token.end if @position >= @text.length
    @res=""
		@rules.each do |rule|
      @res = rule.match(unprocessed_text)
		  next unless @res

      raise Lexr::UnmatchableTextError.new(rule.raises, @position) if @res and rule.raises?

		  @position += @res.characters_matched
		  return self.next if rule.ignore?
		  return @current = @res.token
    end
    if !@default_rule.nil?
      @res=@default_rule.match(unprocessed_text)
      @position += @res.characters_matched
      return @current = @res.token
    end
		raise Lexr::UnmatchableTextError.new(unprocessed_text[0..0], @position)
	end

	def end?
		@current == Lexr::Token.end
  end

  def counter(symbol)
    @counter[symbol]
  end

	private

	def unprocessed_text
		@text[@position..-1]
	end

	class Token
		attr_reader :value, :kind

		def initialize(value, kind = nil)
			@value, @kind = value, kind
		end

		def self.method_missing(sym, *args)
			self.new(args.first, sym)
		end

		def to_s
			"#{kind}(#{value})"
		end

		def ==(other)
    	@kind == other.kind && @value == other.value
		end
	end

	class Rule
		attr_reader :pattern, :symbol, :raises

		def converter ; @opts[:convert_with] ; end
		def ignore? ; @opts[:ignore] ; end
    def raises? ; @opts[:raises] ; end

		def initialize(pattern, symbol, opts = {})
			@pattern, @symbol, @opts = pattern, symbol, opts
      @raises=opts[:raises]
      @counter={}
    end

    def set_counter(counter)
      @counter=counter
    end

	  def match(text)
	    text_matched = self.send :"#{pattern.class.name.downcase}_matcher", text
	    return nil unless text_matched
      increment(@opts[:increment])
      decrement(@opts[:decrement])
	    value = converter ? converter[text_matched] : text_matched
	    Lexr::MatchData.new(text_matched.length, Lexr::Token.new(value, symbol))
    end

		def ==(other)
			@pattern == other.pattern &&
				@symbol == other.symbol &&
				@opts[:convert_with] == other.converter &&
				@opts[:ignore] == other.ignore?
    end

    def counter(symbol)
      puts @counter[symbol]
    end

    def scan(text)
      pat = pattern
      if pattern.is_a?(String)
        pat=/#{Regexp.escape(pattern)}/
      end
      res=text.scan(/#{pat}/)
    end

		private

    def increment(symbol)
      if !symbol.nil?
        @counter[symbol]=0 if @counter[symbol].nil?
        @counter[symbol]+=1
      end
    end

    def decrement(symbol)
      if !symbol.nil?
        @counter[symbol]=0 if @counter[symbol].nil?
        @counter[symbol]-=1
      end
    end

		def string_matcher(text)
		  return nil unless text[0..pattern.length-1] == pattern
      pattern
	  end

	  def regexp_matcher(text)
	    return nil unless m = text.match(/\A#{pattern}/)
		  m[0]
    end
	end

	class Dsl

    attr_reader :available_tokens

		def initialize
			@rules = []
      @default=nil
      @available_tokens=[]
		end

		def matches(rule_hash)
			pattern = rule_hash.keys.reject { |k| k.class == Symbol }.first
			symbol = rule_hash[pattern]
			opts = rule_hash.delete_if { |k, v| k.class != Symbol }
			@rules << Rule.new(pattern, symbol, opts)
      @available_tokens = @available_tokens | [symbol]
    end

    def default(rule_hash)
      pattern = rule_hash.keys.reject { |k| k.class == Symbol }.first
      symbol = rule_hash[pattern]
      opts = rule_hash.delete_if { |k, v| k.class != Symbol }
      @default = Rule.new(pattern, symbol, opts)
    end

		def ignores(rule_hash)
			matches rule_hash.merge(:ignore => true)
    end

		def new(str)
      @counter={}
      @rules.each { |r| r.set_counter(@counter) }
			Lexr.new(str, @rules, @default, @counter)
    end

	end

	class UnmatchableTextError < StandardError
		attr_reader :character, :position

		def initialize(character, position)
			@character, @position = character, position
		end

		def message
			"Unexpected character '#{character}' at position #{position + 1}"
		end

		def inspect
			message
		end
	end

	class MatchData
	  attr_reader :characters_matched, :token

	  def initialize(characters_matched, token)
	    @characters_matched = characters_matched
	    @token = token
    end
  end
end

class String
  #lexer_parse will parse the string using the lexer object passed
  def lexer_parse(lexer)
    @lex=lexer.new(self)
    @lex.parse
  end

  def lexer_counter(symbol)
    raise Lexr::NoLexerError.new("no lexer defined") if @lex.nil?
    @lex.counter(symbol)
  end
end


ExpressionLexer = Lexr.setup {
  matches /\\/ => :escape
  matches /\$[\w]+/ => :variable
  matches /"([^"\\]*(\\.[^"\\]*)*)"/ => :quote
  matches "(" => :l_paren, :increment=>:paren
  matches ")" => :r_paren, :decrement=>:paren
  matches "{" => :l_curly, :increment=>:curly
  matches "}" => :r_curly, :decrement=>:curly
  matches "[" => :l_square, :increment=>:square
  matches "]" => :r_square, :decrement=>:square
  matches "," => :comma
  matches /\s+/ => :whitespace
  matches /[-+]?\d*\.\d+/ => :number, :convert_with => lambda { |v| Float(v) }
  matches /[-+]?\d+/ => :number, :convert_with => lambda { |v| Integer(v) }
  matches "=" => :equals
  matches "\"" => :umatched_quote, :raises=> "Unmatched quote"
  default /[^\s^\\^"^\(^\)^\{^\}^\[^\]^,^=]+/ => :word
}



class Tokenizer < Array

  def initialize(str)
    super()
    replace(str.lexer_parse(ExpressionLexer))
    @available_tokens=ExpressionLexer.available_tokens
  end

  def parse(args={})
    pos=args[:pos] || 0
    pos,tmp=unravel(pos)
    p tmp
    if tmp.length==1 && tmp[0].class==Array
      tmp[0]
    else
      tmp
    end
  end

  #drop
  #drops the first num elements from the tokens array
  def drop(num)
    start=num-1
    self.slice!(start..length)
  end

  def join(str=nil)
    self.map {|i| i.value}.join(str)
  end

  def what_is?(pos,args={})
    return :end if end?(pos)
    return :whitespace if of_type?(pos,:whitespace)
    return :comma if of_type?(pos,:comma)
    return :escape if of_type?(pos,:escape)
    return :paren if of_type?(pos,:paren)
    return :close if close?(pos)
    return :hash if hash?(pos)
    return :array if array?(pos)
    return :simple_array if simple_array?(pos)
    return :assignment if assignment?(pos)
    :other
  end

  def of_type?(pos,types,args={})
    raise "Types must be symbol or array" if !(types.class==Symbol || types.class==Array)
    return false if pos>length-1
    if types.class!=Array
      if ([:element, :open, :close, :hash, :array, :paren] & [types]).empty?
        return self[pos].kind==types
      else
        types=[types]
      end
    end
    valid_types=[]
    valid_types<<[:word,:number,:quote,:variable] if types.delete(:element)
    valid_types<<[:l_curly, :l_paren, :l_square] if types.delete(:open)
    valid_types<<[:r_paren, :r_curly, :r_square] if types.delete(:close)
    valid_types<<[:l_paren] if types.delete(:paren)
    valid_types<<[:l_curly] if types.delete(:hash)
    valid_types<<[:l_square] if types.delete(:array)
    valid_types<<types
    valid_types.flatten!
    !(valid_types & [self[pos].kind]).empty?
  end

  #Walk
  #Parameters:
  # pos, :look_for, :walk_over
  #Will walk over tokens denoted in :walk_over but stop on token symbols denoted in :look_for
  #:walk_over defaults to the whitespace token, returning the position walked to
  #Will start at pos
  #If :look_for is assigned a value walk will walk over :walk_over tokens
  #and stop when the passed token is found.
  #:walk_over and :look_for can be either a single symbol or an array of symbols
  #if :walk_over is nil walk will walk over all tokens until :look_for is found
  #returns the position walked to or nil if :look_for was not found or the end was found
  #If the end was found @pos will never be updated
  def walk(pos,args={})
    look_for = args[:look_for] || []
    look_for=[look_for] if look_for.class!=Array
    look_for.compact!
    walk_over = args[:walk_over] || [:whitespace]
    walk_over=[walk_over] if walk_over.class!=Array
    walk_over.compact!

    start_pos=pos
    raise ":walk_over and :look_for cannot both be empty" if look_for.empty? && walk_over.empty?

    return start_pos if end?(pos)

    if walk_over.empty?
      while !end?(pos) && !(look_for & [self[pos].kind]).empty?
        pos+=1
      end
    else
      while !end?(pos) && !(walk_over & [self[pos].kind]).empty?
        pos+=1
      end
    end
    if !look_for.empty?
      return start_pos if (look_for & [self[pos].kind]).empty?
    end
    pos
  end

  #returns true if the token at pos is a closing token
  #returns true/false if the token at pos is of type :close
  def close?(pos, args={})
    close=args[:close] || nil   #redundancy is for readability
    if close!=nil
      return self[pos].kind==close
    end
    of_type?(pos,:close)
  end

  # Performs a set intersection operator to see if we have a close token as pos
  def open?(pos, open_type=nil)
    return of_type?(pos,:open) if open_type.nil?
    of_type?(pos,open_type)
  end

  def end?(pos, args={})
    close=args[:close] || :nil
    !(pos<length && !close?(pos,:close=>close) && self[pos].kind!=:end)
  end

  def invalid?(pos, invalid_tokens)
    !(invalid_tokens & [self[pos].kind]).empty?
  end

  #assignment?
  #Checks to see if the current position denotes an assignment
  #if :pos is passed it, that wil be used as the starting reference point
  #if :return_pos is passed it will return the associated positions for each
  #element if an assignment is found, otherwise will return nil
  def assignment?(pos, args={})
    return_pos=args[:return_pos] || false
    p1_pos=pos
    (p2_pos = walk(pos+1)).nil? && (return false)
    (p3_pos = walk(p2_pos+1)).nil? && (return false)

    p1=of_type?(p1_pos,:element)
    p2=of_type?(p2_pos,:equals)
    p3=of_type?(p3_pos,[:element, :open])
    is_assignment=p1 && p2 && p3
    if return_pos  #return the positions if it is an assignment, otherwise the result of the test
      is_assignment ? [p1_pos,p2_pos,p3_pos] : nil
    else
      is_assignment
    end
  end

  #Do we have an array?  [1,2,3]
  def array?(pos, args={})
    return false if self[pos].kind==:whitespace
    open?(pos,:array)
  end

  #Do we have a simple array?  "1 2,3,4" -> 2,3,4
  def simple_array?(pos,args={})
    return false if array?(pos)
    p1=pos   # "bla , bla" ->  (p1=bla) (p2=,) (p3=bla)

    #Find the remaining positions.  Return false if walk returns nil
   (p2 = walk(pos+1)).nil? && (return false)
   (p3 = walk(p2+1)).nil? && (return false)

    p1=of_type?(p1,:element)
    p2=of_type?(p2,:comma)
    p3=of_type?(p3,[:element, :open])
    p1 && p2 && p3
  end

  def hash?(pos,args={})
    open?(pos,:hash)
  end

  private

  def invalid_character(pos, args={})
    msg=args[:msg] || "Invalid character found"
    end_pos=args[:end_pos] || pos

    base_msg=msg
    #if $DEBUG
    #  caller[0]=~/(.*):(\d+):.*`(.*?)'/
    #
    #  debug_line=$2.nil? ? "" : $2
    #  debug_func=$3.nil? ? "" : $3
    #  base_msg = "#{$3}-#{$2} "+ msg
    #else
    #  base_msg=msg
    #end

    debug(5,:msg=>"Invalid_Character called by",:stack_pos=>1)

    base_msg+=": \"#{self[0..pos-1].map{|i| i.value}.join if pos>0}\""
    pointer_msg="^".rjust(base_msg.length)
    base_msg=base_msg.chop+self[pos..end_pos].map{|i| i.value}.join+"\""
    puts base_msg
    puts pointer_msg
    raise "#{base_msg} : \"#{self[pos].value}\""
  end


  def get_close(pos)
    case self[pos].kind
      when :l_curly
        :r_curly
      when :l_square
        :r_square
      when :l_paren
        :r_paren
      when :word, :quote, :number
        :whitespace
      else
        nil
    end
  end

  def get_assignment(pos,args={})
    positions=assignment?(pos,:return_pos=>true)
    invalid_character(pos,:msg=>"Invalid assignment") if positions.nil?
    lside=self[positions[0]].value
    if of_type?(positions[2],:element)
      rside=self[positions[2]].value
      pos=positions[2]+1
    elsif of_type?(positions[2],:l_curly)
      pos,rside=get_hash(positions[2])
    else
      pos,rside=unravel(positions[2]+1,:close=>get_close(positions[2]))
    end

    return pos,{lside=>rside}
  end

  def get_hash(pos, args={})
    invalid_character(pos) if self[pos].kind!=:l_curly
    pos+=1
    retval={}
    havecomma=true  #preload the havecomma statement
    while !end?(pos,:close=>:r_curly)
      pos=walk(pos)  #walk over excess whitespace
      if assignment?(pos)  && havecomma
        pos, hashval=get_assignment(pos)
        retval.merge!(hashval)
        havecomma=false
      elsif of_type?(pos,:comma)
        pos+=1
        havecomma=true
      else
        invalid_character(pos, :msg=>"Invalid character found while building hash")
      end
      pos=walk(pos)  #walk over excess whitespace
    end
    pos+=1  #we should be over the closing curly brace, increment position
    invlaid_character if havecomma
    return pos, retval
  end

  def get_escape(pos)
    invalid_character(pos,:msg=>"Escape characters cannot be last") if end?(pos+1)
    pos+=1 #gobble the first escape char
    retval=[]
    while !end?(pos) && self[pos].kind==:escape
      retval<<self[pos].value
      pos+=1
    end
    invalid_character "Unexpected End of String during escape" if end?(pos)
    retval<<self[pos].value
    pos+=1
    return pos,retval.flatten.join
  end

  def unravel(pos,args={})
    close=args[:close] || nil
    if args[:preload]
      retval = []
      retval<<args[:preload]
    else
      retval=[]
    end
    skip_until_close=args[:skip_until_close]==true || false

    raise "Close cannot be nil if skip_until_close" if skip_until_close && close.nil?

    start_pos=pos
    delim=close.nil? ? nil : :comma
    invalid_tokens=[]
    invalid_tokens<<:whitespace if !close.nil? && !([:r_curly,:r_paren,:r_square] & [close]).empty?
    have_item=false

    pos=walk(pos) #skip whitespace
    invalid_character(pos) if invalid?(pos,[:comma]) || close?(pos) #String cannot start with a comma or bracket close

    while !end?(pos,:close=>close)

      invalid_character(pos, :msg=>"Unexpected Close") if close?(pos) && close.nil?

      if of_type?(pos,:escape)
        pos,result=get_escape(pos)
        retval<<result
        next
      end

      if skip_until_close
        retval<<self[pos].value
        pos+=1
        pos=walk(pos)
        next
      end

      case what_is?(pos)
        when :escape
          pos,result=get_escape(pos)
          retval<<result
        when :paren
          pos,result=unravel(pos+1,:close=>get_close(pos),:skip_until_close=>true)
          retval<<"("
          result.each {|i| retval<<i }
          retval<<")"
          have_item=true
        when :hash
          pos,result=get_hash(pos)
          retval<<result
          have_item=true
        when :array
          pos,result=unravel(pos+1,:close=>get_close(pos))
          retval<<result
          have_item=true
        when :simple_array
          #if our delimiter is a comma then we've already detected the simple array
          if delim==:comma
            retval<<self[pos].value
            pos+=1
            have_item=true
          else
            pos,result=unravel(pos,:close=>:whitespace)
            retval<<result
            have_item=false
          end
        when :assignment
          pos,result=get_assignment(pos)
          retval<<result
          have_item=true
        when :comma
          if delim!=:comma
            last=retval.pop
            pos+=1
            pos,result=unravel(pos,:close=>:whitespace, :preload=>last)
            retval<<result
          end
          have_item=false
          pos+=1
        when :whitespace
          return pos, retval if have_item && close==:whitespace
          pos+=1
        when :close
          invalid_character(pos,:msg=>"Unexpected close") if self[pos].kind!=close
          pos+=1
          return pos,retval
        when :other
          if have_item && close==:whitespace
            return pos,retval
          end
          have_item=true
          retval<<self[pos].value
          pos+=1
        else #case what_is?(pos)
          invalid_character(pos)
      end #case what_is?(pos)
      pos=walk(pos)  #walk whitespace ready for next round
    end
    pos+=1

    return pos, retval
  end
end



#p test_str="\"test\"=test1,2.0,3, 4 \"quote test\" value = { a = { b = [ c = { d = [1,a,g=f,3,4] }, e=5,6,7,8] } }"
#p test_str="value = { a = { b = [ c = { d = [1,a,g=f,3,4] }, e=5,6,7,8] } }"
#p test_str="test=4, 5, 6, 7  {a={b=4,c=5}} test2=[1,2,[3,[4]],5] value=9, 9"
#p test_str="a=[1,2] b={g=2} c 1,two,[1.1,1.2,1.3,[A]],three,4 d e[1,2] "
#p test_str="word1 word2,word3 , d , e,"
#p test_str="  test   a=1, bla {b={c=2}}"
#p test_str="a=b \\(a=c\\)"
#p test_str="\\)"

#p tokens=Tokenizer.new(test_str)
#p result=tokens.parse

