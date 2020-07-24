# frozen_string_literal: true

require 'parser/current'
require "interpretr/version"
require "interpretr/sandbox"
require "interpretr/capabilities"

module Interpretr
  class Error < StandardError; end

  def self.run(source, parser: ::Parser::CurrentRuby, **rest)
    ast = parser.parse(source)
    Sandbox.new(ast).run(rest)
  end
end
