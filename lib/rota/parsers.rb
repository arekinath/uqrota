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

		rule(:coursecode) { (match('[A-Z]').repeat(4,4) >> match('[0-9]').repeat(4,4) >> match('[A-Z]').repeat(1,2).maybe) | (match('[A-Z]').repeat(3,3) >> match('[0-9]').repeat(3,3)) | stri("equivalent") }
		rule(:operator) { stri('and') | stri('or') | stri('xor') | str('+') | str('|') | str('&') }
		rule(:opspec) { parenspec.as(:base) >> (space >> operator.as(:operator) >> space >> (spec.as(:spec) | match('[0-9]').repeat(1,4).as(:stem))).repeat(1) }

		rule(:comma) { space? >> str(',') >> space? }
		rule(:semicolon) { space? >> str(';') >> space? }
		rule(:slash) { space? >> str('/') >> space? }

		rule(:commalist) { parenspec.as(:spec) >> (comma >> spec.as(:spec)).repeat(1) }
		rule(:semilist) { parenspec.as(:spec) >> (semicolon >> spec.as(:spec)).repeat(1) }
		rule(:slashlist) { parenspec.as(:spec) >> (slash >> spec.as(:spec)).repeat(1) }
		rule(:spacelist) { parenspec.as(:spec) >> (space >> spec.as(:spec)).repeat(1) }
		rule(:list) { commalist | semilist | slashlist | spacelist }

		rule(:parenspec) { (str('(') >> space? >> spec.as(:spec) >> space? >> str(')')) | coursecode.as(:course) }
		rule(:spec) { opspec.as(:operation) | list.as(:list) | parenspec.as(:spec) }

		rule(:top) { space | (space? >> spec.as(:expression) >> space? >> str('.') >> space? >> any.repeat) | (space? >> spec.as(:expression) >> space?) }

		root :top
	end

end
