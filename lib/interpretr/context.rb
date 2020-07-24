# # frozen_string_literal: true

# module Interpretr
#   class Context

#     attr_reader :ivars,
#                 :contexts

#     def initialize
#       # @ivars = Variables.new('instance', {})
#       @contexts = []
#     end

#     def with(object)
#       contexts.unshift(object)
#       yield
#     ensure
#       contexts.shift
#     end

#     def current
#       contexts.last
#     end

#   end
# end
