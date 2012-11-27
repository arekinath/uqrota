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
		rule(:hssubj) { stri('maths') | stri('english') | stri('science') | stri('chemistry') | stri('biology') }
		rule(:highschool) {
			((hsgrade.as(:grade) >> space >> (str("in") >> space).maybe).maybe >> stri("year") >> space >> match('[0-9]').repeat(1).as(:year) >> space >> match('[a-zA-Z]').repeat(1).as(:subject) >> (space >> match('[A-Z]').repeat(1,2).as(:suffix)).maybe) |
			(hssubj.as(:subject) >> (space >> match('[a-zA-Z]').repeat(1,2).as(:suffix)).maybe)
		}
		rule(:equivalent) { stri('equivalent') | stri('equiv.') | stri('equiv') }
		rule(:coursecode) {
			(match('[A-Z]').repeat(4,4).as(:root) >> (match('[0-9]').repeat(4,4) >> match('[A-Z]').repeat(1,2).maybe).as(:stem)) |
			(match('[A-Z]').repeat(3,3).as(:root) >> match('[0-9]').repeat(3,3).as(:stem))
		}
		rule(:courselike) { equivalent.as(:equivalent) | highschool.as(:highschool) | coursecode.as(:course) }

		rule(:xorop) { stri('xor') | str('^') }
		rule(:andop) { stri('and') | str('+') | str('&') | str(',') | str(';') }
		rule(:orop) { stri('or') | str('|') }

		rule(:xorspec) { parenspec.as(:left) >> (space? >> xorop >> space? >> parenspec.as(:right)).repeat(1) }
		rule(:andspec) { (xorspec.as(:one_of) | parenspec).as(:left) >>
						(space? >> andop >> space? >>
						 (xorspec.as(:one_of) | parenspec).as(:right)).repeat(1) }
		rule(:orspec) { (xorspec.as(:one_of) | andspec.as(:all_of) | parenspec).as(:left) >>
						(space? >> orop >> space? >>
						(xorspec.as(:one_of) | andspec.as(:all_of) | parenspec).as(:right)).repeat(1) }

		rule(:parenspec) {
			(str('(') >> space? >> spec >> space? >> str(')')) |
			(str('[') >> space? >> spec >> space? >> str(']')) |
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
			(any.repeat(1) >> str('.') >> space? >> spec) |
			(spec >> str('.') >> space? >> any.repeat(1)) |
			spec |
			str(" ") |
			str("")
		}

		root :top
	end

end
