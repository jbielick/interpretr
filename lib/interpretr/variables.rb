# frozen_string_literal: true

module Interpretr
  class Variables

    attr_reader :type

    def initialize(type:)
      @type = type
    end

    def with(map)
      scopes.unshift(map)
      yield
    ensure
      scopes.shift
    end

    def set(name, value)
      scope_for(name)[name] = value
    end

    def get(name, &block)
      scope_for(name).fetch(name, &block)
    end

    def get!(name)
      get(name) do
        raise NameError, "undefined #{type} variable `#{name}'"
      end
    end

    def clear
      @scopes = nil
    end

    private

    def scopes
      @scopes ||= []
    end

    def current_scope
      scopes.first
    end

    def scope_for(name)
      scopes.detect { |map| map.key?(name) } || current_scope
    end

  end
end
