require 'parslet'

module Rota

	class PrereqParser < Parslet::Parser
		def stri(str)
			key_chars = str.split(//)
			key_chars.
				collect! { |char| match["#{char.upcase}#{char.downcase}"] }.
				reduce(:>>)
		end

		rule(:space) { match('\s').repeat(1) }
		rule(:space?) { match('\s').repeat }

		rule(:hsgrade) { stri('LA') | stri('SA') | stri('HA') | stri('VHA') }
		rule(:hssubj) { stri('maths') | stri('english') | stri('science') | stri('chemistry') | stri('biology') | stri('japanese') | stri('french') | stri('german') }
		rule(:highschool) {
			((hsgrade.as(:grade) >> space >> (str("in") >> space).maybe).maybe >> (stri("year") | stri('yr')) >> space >> match('[0-9]').repeat(1).as(:year) >> space >> match('[a-zA-Z]').repeat(1).as(:subject) >> (space >> match('[A-Z]').repeat(1,2).as(:suffix)).maybe) |
			(hssubj.as(:subject) >> (space >> match('[a-zA-Z]').repeat(1,2).as(:suffix)).maybe)
		}
		rule(:equivalent) { stri('equivalent') | stri('equiv.') | stri('equiv') }
		rule(:coursecode) {
			(match('[A-Z]').repeat(4,4).as(:root) >> (match('[0-9]').repeat(4,4) >> match('[A-Z]').repeat(1,2).maybe).as(:stem)) |
			(match('[A-Z]').repeat(2,3).as(:root) >> match('[0-9]').repeat(3,3).as(:stem))
		}
		rule(:courselike) { equivalent.as(:equivalent) | highschool.as(:highschool) | coursecode.as(:course) }

		rule(:xorop) { stri('xor') | str('^') | str('/') }
		rule(:andop) { stri('and either') | stri('and') | str('+') | str('&') | str(',') | str(';') }
		rule(:orop) { stri('or') | str('|') }

		rule(:xorspec) { parenspec.as(:left) >> (space? >> xorop >> space? >> parenspec.as(:right)).repeat(1) }
		rule(:andspec) { (xorspec.as(:one_of) | parenspec).as(:left) >>
						(space? >> andop >> space? >>
						 (xorspec.as(:one_of) | parenspec).as(:right)).repeat(1) }
		rule(:orspec) { (andspec.as(:all_of) | xorspec.as(:one_of) | parenspec).as(:left) >>
						(space? >> orop >> space? >>
						(andspec.as(:all_of) | xorspec.as(:one_of) | parenspec).as(:right)).repeat(1) }

		rule(:parenspec) {
			(str('(') >> space? >> spec >> space? >> str(')')) |
			(str('[') >> space? >> spec >> space? >> str(']')) |
			(str('{') >> space? >> spec >> space? >> str('}')) |
			match('[0-9]').repeat(1,4).as(:stem) |
			courselike
		}

		rule(:spec) {
			orspec.as(:any_of) |
			andspec.as(:all_of) |
			xorspec.as(:one_of) |
			parenspec
		}

		rule(:top) {
			(space? >> stri('for') >> space >> courselike >> space? >> str(':') >> space? >> (stri("prereq") >> stri('s').maybe).maybe >> space? >> spec).repeat(1) |
			(any.repeat(1) >> (str('.') | str(';')) >> space? >> spec >> space?) |
			(space? >> spec >> (str('.') | str(';')) >> space? >> any.repeat(1)) |
			space? >> spec >> space? |
			space |
			str("")
		}

		root :top
	end

end
