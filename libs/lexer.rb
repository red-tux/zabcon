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

require 'libs/zabcon_exceptions'
#require 'zbxapi/exceptions'
#require "zbxapi/zdebug"

class InvalidCharacterSuper <ZabconError
  attr_accessor :invalid_char, :invalid_str, :position

  def initialize(message=nil, params={})
    super(message,params)
    @message=message || "Invalid Character"
    @position=params[:position] || nil
    @invalid_char=params[:invalid_char] || nil
    @invalid_str=params[:invalid_str] || raise(RuntimeError.new(":invalid_str required",:retry=>false))
  end

  def show_message
    preamble="#{@message}  \"#{@invalid_char}\" : "
    pointer="^".rjust(@position+preamble.length+1)
    puts preamble+@invalid_str
    puts pointer
  end
end


#This is a wrapper class for creating a generalized lexer.
class Lexr

  class NoLexerError < ZError
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
    tokens=[]
    until self.end?
      tokens << self.next
    end

    join_escape(tokens)
  end

  def join_escape(tokens)
    tmp=[]
    escapes=0
    tokens=tokens.map do |i|
      if i.kind==:escape
        escapes+=1
        tmp<<i.value
        nil
      elsif escapes>0 && i.kind!=:end
        escapes=0
        tmp<<i.value
        token=Token.new(tmp.join.to_s,:escape)
        tmp=[]
        token
      else
        i
      end
    end.compact
    if escapes>0
      tokens[-1]=Token.new(tmp.join.to_s,:escape)
      tokens<<Lexr::Token.end
    end
    tokens
  end

	def next
		return @current = Lexr::Token.end if @position >= @text.length
    @res=""
		@rules.each do |rule|
      @res = rule.match(unprocessed_text)
		  next unless @res

      raise Lexr::UnmatchableTextError.new(rule.raises, :position=>@position,:invalid_str=>@text) if @res and rule.raises?

		  @position += @res.characters_matched
		  return self.next if rule.ignore?
		  return @current = @res.token
    end
    if !@default_rule.nil?
      @res=@default_rule.match(unprocessed_text)
      @position += @res.characters_matched
      return @current = @res.token
    end
		raise Lexr::UnmatchableTextError.new(unprocessed_text[0..0], :position=>@position,:invalid_str=>@text)
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

  #class Token
  #Token dynamically generates sub classes when Token.new is called
  #The sub classes are descendant from Lexr::Token::Sub
  class Token
    class Sub
      attr_reader :value

    		def initialize(value)
          @value = value
        end

        def to_s
    			"#{kind}(#{value})"
    		end

    		def ==(other)
        	self.class == other.class && @value == other.value
        end

        def is_a?(obj)
          if obj.class==Symbol
            obj==self.class.to_s.split("::")[-1].downcase.intern
          else
            super(obj)
          end
        end

        def kind
          self.class.to_s.split("::")[-1].downcase.intern
        end
    end

    class Variable < Sub
      def set_value(val)
        @value=val
      end
    end

    def self.new(value,kind=nil)
      obj_name=kind.to_s.capitalize
      begin
        #    self::Sub.new(value,kind,opts)
        obj=self.const_get(obj_name)
        obj.new(value)
      rescue NameError
        self.const_set(obj_name,Class.new(Token::Sub))
        retry
      end
    end

  	def self.method_missing(sym, *args)
  		self.new(args.first, sym)
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
      @counter[symbol]
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

	class UnmatchableTextError < InvalidCharacterSuper

		def initialize(message=nil, params={})
      params[:retry]||=true
      params[:invalid_char]=params[:invalid_str][params[:position]]
      super(message,params)
		end

		def message
			"#{@message} '#{@invalid_char}' at position #{position + 1}"
    end

    def show_message
      preamble="#{@message}  : "
      pointer="^".rjust(@position+preamble.length+1)
      puts preamble+@invalid_str
      puts pointer
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
#  matches /\\\"/ =>
  matches /\$[\w]+/ => :variable
  matches /"([^"\\]*(\\.[^"\\]*)*)"/ => :quote, :convert_with=>lambda {|v| v[1,v.length-2]}
  matches /"([^'\\]*(\\.[^'\\]*)*)"/ => :quote, :convert_with=>lambda {|v| v[1,v.length-2]}
  matches "(" => :l_paren, :increment=>:paren
  matches ")" => :r_paren, :decrement=>:paren
  matches "{" => :l_curly, :increment=>:curly
  matches "}" => :r_curly, :decrement=>:curly
  matches "[" => :l_square, :increment=>:square
  matches "]" => :r_square, :decrement=>:square
  matches "," => :comma
  matches /\s+/ => :whitespace
  matches /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ => :ipv4
  matches /[-+]?\d*\.\d+/ => :number, :convert_with => lambda { |v| Float(v) }
  matches /[-+]?\d+/ => :number, :convert_with => lambda { |v| Integer(v) }
  matches "=" => :equals
  matches "\"" => :umatched_quote, :raises=> "Unmatched quote"
  matches /#.*$/ => :comment
  default /[^\s^\\^"^'^\(^\)^\{^\}^\[^\]^,^=]+/ => :word
}

CommandLexer = Lexr.setup {
  matches /\\/ => :escape
  matches /\$[\w]+/ => :variable
  matches /"([^"\\]*(\\.[^"\\]*)*)"/ => :quote
  matches /"([^'\\]*(\\.[^'\\]*)*)"/ => :quote
  matches /\s+/ => :whitespace
  matches /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ => :ipv4
  matches /[-+]?\d*\.\d+/ => :number, :convert_with => lambda { |v| Float(v) }
  matches /[-+]?\d+/ => :number, :convert_with => lambda { |v| Integer(v) }
  matches "=" => :equals
  matches "\"" => :umatched_quote, :raises=> "Unmatched quote"
  matches /#.*$/ => :comment
  default /[^\s^=^\$^"^']+/ => :word
}

SimpleLexer = Lexr.setup{
  matches /"([^"\\]*(\\.[^"\\]*)*)"/ => :quote
  matches /"([^'\\]*(\\.[^'\\]*)*)"/ => :quote
  matches /\s+/ => :whitespace
  matches "\"" => :umatched_quote, :raises=> "Unmatched quote"
  matches /#.*$/ => :comment
  default /[^\s^"^']+/ => :word
}

#Base Class for all Tokenizers
#Inherits from Array
class Tokenizer < Array
  include ZDebug

  class NoLexer < ZabconError
    def initialize(message=nil, params={})
      super(message,params)
      @message=message || "No Lexer Passed"
    end
  end

  class InvalidCharacter <InvalidCharacterSuper
  end

  attr_accessor :parsed
  attr :items

  #Base class version of initialize
  #Will raise an exception if a Lexer is not passed in.
  #Takes a string str and and hash arguments and creates a Lexical token reference of str
  #It will also parse the lexical tokens into an array of items.
  #:keep_escape determines weather or not to keep all escape backslashes, default false
  def initialize(str,args={})
    super()
    raise NoLexer.new if args[:lexer].nil?
    debug(8,:msg=>"Initial String",:var=>str.inspect)
    replace(str.lexer_parse(args[:lexer]))  #replace self with array from lexer_parse
    debug(8,:msg=>"Tokens",:var=>self)
    debug(8,:msg=>"Tokens(Length)",:var=>length)
    @available_tokens=args[:lexer].available_tokens
    @class_options||=[]

    if @class_options.include?(:remove_whitespace)
      delete_if do |i|
        i.kind==:whitespace
      end
    end

  end

  def parse(args={})
    raise BaseClassError.new
  end

  #Creates a factory to dynamicly generate a new descendant object with
  #the options passed in, which are available via the variable @class_options
  #*options : array of symbols
  def self.options(*options)
    if options.nil?
      self
    else
      class_name=self.to_s+"_"+options.map {|i| i.to_s}.join
      str =<<-EOF
        class #{class_name} < self
          def initialize(str,args={})
            @class_options=#{options.inspect}
            super(str,args)
          end
        end
      EOF
      eval(str)
      eval(class_name)
    end
  end

  def to_s
    self.map{|i|
      if i.kind==:quote
        "#{i.value}"
      else
        i.value
      end
    }.join
  end
end

class BasicExpressionTokenizer < Tokenizer
  def initialize(str,args={})
    args[:lexer]||=ExpressionLexer
    super(str,args)
    #@parsed=parse(args)
    #@items=@parsed.clone
  end

  def parse
    map {|i|  #SimpleTokenizer inherits from Array
      next if i.kind==:end
      i.value
    }.compact

  end

end

#TODO Clean up code now that Lexr::Token is a dynamic class generator
class ExpressionTokenizer < Tokenizer

  class UnexpectedClose < InvalidCharacter
    def initialize(message=nil, params={})
      super(message,params)
      @message=message || "Invalid Character"
    end
  end

  class DelimiterExpected < InvalidCharacter
    def initialize(message=nil, params={})
      super(message,params)
      @message=message || "Delimiter expected"
    end
  end

  class ItemExpected < InvalidCharacter
    def initialize(message=nil, params={})
      super(message,params)
      @message=message || "Item expected"
    end
  end

  class WhitespaceExpected < InvalidCharacter
    def initialize(message=nil, params={})
      super(message,params)
      @message=message || "Whitespace expected"
    end
  end

  class EscapeEnd < InvalidCharacter
    def initialize(message=nil, params={})
      super(message,params)
      @message=message || "Cannot escape the end of a string"
    end
  end

  attr_accessor :parsed
  attr :items

  #Takes a string str and and hash arguments and creates a Lexical token reference of str
  #It will also parse the lexical tokens into an array of items.
  #:keep_escape determines weather or not to keep all escape backslashes, default false
  def initialize(str,args={})
    args[:lexer]||=ExpressionLexer
    super(str,args)
    #@parsed=parse(args)
    #@items=@parsed.clone
  end

  def parse(args={})
    pos=args[:pos] || 0
    args.delete(:pos)
    pos,tmp=unravel(pos,args)
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
    return :comment if of_type?(pos,:comment)
    return :paren if of_type?(pos,:paren)
    return :close if close?(pos)
    return :hash if hash?(pos)
    return :array if array?(pos)
#    return :simple_array if simple_array?(pos)
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

  def invalid_character(pos, args={})
    msg=args[:msg] || nil
    end_pos=args[:end_pos] || pos
    error_class=args[:error] || InvalidCharacter
    if !error_class.class_of?(ZError)
      raise ZError.new("\"#{error_class.inspect}\" is not a valid class.  :error must be of class ZError or a descendant.", :retry=>false)
    end
    retry_var=args[:retry] || true

    debug(5,:msg=>"Invalid_Character (function/line num is caller)",:stack_pos=>1,:trace_depth=>4)

    invalid_str=self[0..pos-1].join || ""
    position=invalid_str.length
    invalid_str+=self[pos..self.length-1].join if !invalid_str.empty?
    invalid_char=self[pos].value
    raise error_class.new(msg, :invalid_str=>invalid_str,:position=>position,:invalid_char=>invalid_char, :retry=>retry_var)
  end

  private

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

  def get_escape(pos,args={})
    keep_initial=args[:keep_escape] || false
    debug(8,:msg=>"(#{self[pos].value.inspect}).length => #{self[pos].value.length}")
    invalid_character(pos, :error=>EscapeEnd) if self[pos].value.length==1 && end?(pos+1)

    return pos+1,self[pos].value if keep_initial
    return pos+1,self[pos].value[1..self[pos].value.length]
  end

  class Status

    def initialize(pos,tokenizer,args={})
      @named_vars=[:close, :nothing_seen, :delim, :have_delim, :have_item,
                   :item_seen, :delim_seen]

      @tokenizer=tokenizer

      @stat_hash={}
      @named_vars.each {|i| @stat_hash[i]=nil}  #preload for debugging
      self.have_item = self.have_delim =  self.delim_seen = false
      @stat_hash.merge!(args) #args overwrites @stat_hash where keys are equal

      self.item_seen=@stat_hash[:preload].nil?

      #If we expect to find a closing element, the delimiter will be a comma
      #Otherwise we'll discover it later
      self.delim=:comma if self.delim.nil? && !self.close.nil?

      self.skip_until_close=self.skip_until_close==true || false #enforce boolean result
    end

    def args
      hash={}
      vars=instance_variables
      vars.delete("@tokenizer")
      vars.delete("@stat_hash")
      vars.delete("@named_vars")
      vars.each do |i|
        hash.merge!(i.split("@")[-1].to_sym=>instance_variable_get(i))
      end
      hash.merge!(@stat_hash)
    end

    def merge(other_hash)
      raise ZError.new("Hash Value required",:retry=>false) if other_hash.class!=Hash
      args.merge(other_hash)
    end

    def inspect
      "#<#{self.class}:0x#{self.__id__.to_s(16)} " + args.inspect + ">"
    end

    def []=(key,value)
      @stat_hash[key]=value
    end

    def [](key)
      @stat_hash[key]
    end

    def method_missing(sym,*args)
      key=sym.to_s.split("=")[0].intern
      have_equal=(key.to_s!=sym.to_s)
      val=@stat_hash[key]
      return val if val && !have_equal && args.empty?

      if have_equal
        @stat_hash[key]=*args
        return *args
      end

      #just to be sure let's kick this to the super class, otherwise return nil
      begin
        return super(sym,args)
      rescue NoMethodError
        return nil
      end
    end

    def item(pos)
      #set the delimiter to whitespace if we've never seen a delimiter but have an item
      if self.delim.nil? && self.have_item && !self.delim_seen
        self.delim=:whitespace
        self.delim_seen=true
      end

      @tokenizer.invalid_character(pos, :error=>DelimiterExpected) if
          self.have_item && self.delim!=:whitespace && !@tokenizer.of_type?(pos,[:open,:close])
      self.item_seen=true
      self.have_item=true
      self.have_delim=false
    end

    def delimiter(pos)
      if @tokenizer.of_type?(pos,:comma)
        @tokenizer.invalid_character(pos,:error=>WhitespaceExpected) if self.delim==:whitespace
        @tokenizer.invalid_character(pos,:error=>ItemExpected) if self.delim==:comma and self.have_delim
      elsif @tokenizer.of_type?(pos,:whitespace)
        self.delim=:whitespace if self.delim.nil? && self.seen_item
      else
        @tokenizer.invalid_character(pos)
      end

      self.delim_seen=true
      self.have_item=false
      self.have_delim=true
    end

  end

  def unravel(pos,args={})
    status=Status.new(pos,self,args)
    status[:start_pos]=pos

    if args[:preload]
      retval = []
      retval<<args[:preload]
    else
      retval=[]
    end

#    raise "Close cannot be nil if skip_until_close" if status.skip_until_close && status.close.nil?

    debug(8,:msg=>"Unravel",:var=>[status,pos])

    invalid_tokens=[]
    invalid_tokens<<:whitespace if !status.close.nil? && !([:r_curly,:r_paren,:r_square] & [status.close]).empty?

    pos=walk(pos) #skip whitespace
    invalid_character(pos) if invalid?(pos,[:comma]) || close?(pos) #String cannot start with a comma or bracket close

    while !end?(pos,:close=>status.close)
      begin
        debug(8,:msg=>"Unravel-while",:var=>[pos,self[pos]])
        debug(8,:msg=>"Unravel-while",:var=>[status,status.have_item,status.close])
        debug(8,:msg=>"Unravel-while",:var=>retval)

        invalid_character(pos,:error=>UnexpectedClose) if close?(pos) && status.close.nil?

        if status.skip_until_close
          debug(8,:msg=>"skip_until_close",:var=>[pos,self[pos]])
          retval<<self[pos].value
          pos+=1
          pos=walk(pos)
          next
        end

        case what_is?(pos)
          when :comment
            return pos,retval if !status.keep_comment
            retval<<self[pos].value
            return pos,retval
          when :escape
            status.item(pos)
            pos,result=get_escape(pos,status.args)
            retval<<result
          when :paren
            status.item(pos)
            pos,result=unravel(pos+1,:close=>get_close(pos),:skip_until_close=>true)
            retval<<"("
            result.each {|i| retval<<i }
            retval<<")"
          when :hash
            debug(8,:msg=>"hash",:var=>[pos,self[pos]])
            status.item(pos)
            pos,result=get_hash(pos)
            debug(8,:msg=>"hash-return",:var=>[pos,self[pos]])
            retval<<result
          when :array
            status.item(pos)
            pos,result=unravel(pos+1,:close=>get_close(pos))
            retval<<result
          #when :simple_array
          #  #if our delimiter is a comma then we've already detected the simple array
          #  if delim==:comma
          #    retval<<self[pos].value
          #    pos+=1
          #    have_item=true
          #  else
          #    pos,result=unravel(pos,:close=>:whitespace)
          #    retval<<result
          #    have_item=false
          #  end
          when :assignment
            status.item(pos)
            debug(8,:msg=>"assignment",:var=>[pos,self[pos]])
            pos,result=get_assignment(pos)
            debug(8,:msg=>"assignment-return",:var=>[pos,self[pos]])
            retval<<result
            have_item=true
          when :comma, :whitespace
            begin
              status.delimiter(pos)
            rescue WhitespaceExpected
              last=retval.pop
              pos+=1
              pos,result=unravel(pos,:close=>:whitespace, :preload=>last)
              retval<<result
            end
            return pos, retval if status.have_item && status.close==:whitespace
            pos+=1
          when :close
            invalid_character(pos,:error=>UnexpectedClose) if self[pos].kind!=status.close
            pos+=1
            return pos,retval
          when :other
            debug(8,:msg=>"Unravel-:other",:var=>[self[pos]])
            status.item(pos)
            #if status.have_item && status.close==:whitespace
            #  return pos,retval
            #end
            retval<<self[pos].value
            pos+=1
          else #case what_is?(pos)
            invalid_character(pos)
        end #case what_is?(pos)
        debug(8,:msg=>"walk",:var=>[pos,self[pos]])
        pos=walk(pos)  #walk whitespace ready for next round
        debug(8,:msg=>"walk-after",:var=>[pos,self[pos]])
      rescue DelimiterExpected=>e
        debug(8,:var=>caller.length)
        debug(8,:var=>status)
        debug(8,:var=>[pos,self[pos]])
        if status.delim==:comma && status.have_item
          debug(8)
          return pos,retval
        else
          debug(8)
          raise e
        end
        debug(8)
      end
    end
    invalid_character(pos) if status.have_delim && status.delim==:comma
    pos+=1
    debug(8,:msg=>"Unravel-While-end",:var=>[have_item, status.delim])

    return pos, retval
  end
end

class ExpressionTokenizerHash < ExpressionTokenizer

  @default_val = true

  class InvalidItem <ZabconError
    attr_accessor :invalid_item

    def initialize(message=nil, params={})
      super(message,params)
      @message=message || "Invalid Token"
      @invalid_item=params[:invalid_item] || nil
    end

    def show_message
      puts "#{@message}  \"#{@invalid_item}\""
    end
  end


  def parse(args={})
    parsed=super(args)
    ret_hash={}
    parsed.each do |item|
      if item.is_a?(Hash)
        val=item
      elsif item.is_a?(Numeric) || item.is_a?(String)
        val={item.to_s=>@default_val}
      else
        raise InvalidItem.new("Invalid token for hash key",:invalid_item=>item.to_s)
      end
      ret_hash.merge!(val)
    end
    ret_hash
  end

end

class CommandTokenizer < ExpressionTokenizer
  def initialize(str,args={})
    args[:lexer]||=CommandLexer

    super(str,args)
  end
end

class SimpleTokenizer < BasicExpressionTokenizer
  def initialize(str,args={})
    args[:lexer]||=SimpleLexer

    super(str,args)
  end
end

class SimpleTokenizerString < SimpleTokenizer
  def parse
    super.join
  end
end


def walk(tokens,pos,skip=[:whitespace])
  pos+=1 while (pos<tokens.length &&
      !(skip & [tokens[pos].kind]).empty? &&
      tokens[pos].kind!=:end)
  pos
end

def group(tokens)
  retval,=group2(tokens,[])
  retval
end

def group2(tokens,stack)
  raise "Empty tokens" if tokens.empty?

  retval=[]
  need_comma=stack.length>0

  pos=-1
  while ((pos+=1)<tokens.length)
    case tokens[pos].kind
      when stack[-1]
        return retval,pos+1
      when :end
        return retval,pos+1
      when :word, :number, :variable, :escape
        lpos= stack[-1]==:whitespace ? pos+1 : lpos=walk(tokens,pos+1)
        if tokens[lpos].kind==:equals
          new_stack=stack.empty? ? [:whitespace] : stack+[stack[-1]]
          lside=tokens[pos]
          rside, lpos=group2(tokens[lpos+1..-1], new_stack)
          pos+=lpos
          retval<<{lside => rside}
        elsif tokens[lpos].kind==:comma && !need_comma
          new_stack=stack.empty? ? [:whitespace] : stack+[stack[-1]]
          ret, pos=group2(tokens[pos..-1], new_stack)
          retval<<ret
        else
          retval<<tokens[pos]
        end
      when :l_square
        rside, lpos=group2(tokens[pos+1..-1],stack+[:r_square])
        pos+=lpos
        retval<<rside
      when :comma
        raise "Unexpected comma" if !need_comma
      when :whitespace
        #do nothing
      else
        puts "pos: #{pos}"
        puts "tokens[pos]: #{tokens[pos].inspect}"
        puts "stack: #{stack.inspect}"
        exit
    end
  end

  return retval,pos
end


if ($0==__FILE__)

  include ZDebug
  set_debug_level(1)
  require "pp"
  #p test_str="\"test\"=test1,2.0,3, 4 \"quote test\" value = { a = { b = [ c = { d = [1,a,g=f,3,4] }, e=5,6,7,8] } }"
  #p test_str="value = { a = { b = [ c = { d = [1,a,g=f,3,4] }, e=5,6,7,8] } }"
  #p test_str="test=4, 5, 6, 7  {a={b=4,c=5}} test2=[1,2,[3,[4]],5] value=9, 9"
  #p test_str="a=[1,2] b={g=2}   c 1,two,[1.1,1.2,1.3,[A]],three,4 d e[1,2] $var"
  #p test_str="word1 word2,word3 , d , e,"
  #p test_str="  test   a=1, bla {b={c=2}}"
  #p test_str="a=b \\(a=c\\)"
  #p test_str="\\)"
  #p test_str="a=b=[c, d] a [1,2] $var=5"
  p test_str="filter={name1=\"A Server\",name2=\"Joe's server\",name3=\"Maria's \\\"Server\\\"\"}"

  pp tokens=ExpressionTokenizer.new(test_str)
  puts "----"

  p tokens.to_s
  pp result=tokens.parse
  #puts "----"
  #pp group(tokens)
end

