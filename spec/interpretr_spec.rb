# frozen_string_literal: true

RSpec.describe Interpretr do

  it "has a version number" do
    expect(Interpretr::VERSION).not_to be nil
  end

  context '.run' do

    {
      'strings' => [
        {
          source: <<-RUBY,
            'streeng'
          RUBY
          expectation: 'streeng',
        },
        {
          source: <<-RUBY,
            "dqstring"
          RUBY
          expectation: 'dqstring',
        },
        {
          source: <<-RUBY,
            %{alternative}
          RUBY
          expectation: 'alternative',
        },
        {
          source: <<-RUBY,
            %q{anotheralt}
          RUBY
          expectation: 'anotheralt',
        },
      ],
      'integers' => [

      ],
      'boolean logic' => [
        {
          source: <<-RUBY,
            !(false || true) || false
          RUBY
          expectation: false,
        },
        {
          source: <<-RUBY,
            (false || true) || false
          RUBY
          expectation: true,
        },
        {
          source: <<-RUBY,
            true && false
          RUBY
          expectation: false,
        },
        {
          source: <<-RUBY,
            true && true
          RUBY
          expectation: true,
        },
        {
          source: <<-RUBY,
            true && 1 && 's' && :sym && 1.2
          RUBY
          expectation: 1.2,
        },
      ],
      'conditionals' => [
        {
          source: <<-RUBY,
            name = nil
            if name.nil?
              'true'
            else
              'false'
            end
          RUBY
        },
        {
          source: <<-RUBY,
            name = nil
            unless name.nil?
              'false'
            else
              'true'
            end
          RUBY
        },
        {
          source: <<-RUBY,
            if false
              fail
            end
          RUBY
        },
        {
          source: <<-RUBY,
            if false
              fail
            elsif false
              fail
            end
          RUBY
        },
      ],
      'negation' => [
        {
          source: '!false',
          expectation: true,
        }
      ],
      'local variables / scoping' => [
        {
          source: <<-RUBY,
            name = 'Joe' * 4
            name
          RUBY
          expectation: "JoeJoeJoeJoe",
        },
        {
          source: <<-RUBY,
            name = 'Joe'
            begin
              name = 'Jane'
            end
            name
          RUBY
          expectation: "Jane",
        },
        {
          title: 'outer access of inner scope',
          source: <<-RUBY,
            block = proc { name = 'Toby' }
            block.call
            name rescue 'not defined'
          RUBY
          # expectation: 'not defined'
        },
        {
          title: 'deconstruction 1',
          source: <<-RUBY,
            array = [1, 2, 3]
            one, two, three = array
            [one, two, three]
          RUBY
        },
        {
          title: 'deconstruction 2',
          source: <<-RUBY,
            one, two, three = 1
            [one, two, three]
          RUBY
        },
        {
          metadata: :focus,
          title: 'deconstruction 3',
          source: <<-RUBY,
            a, (b, *c), *d = 1, [2, 3, 4], 5, 6
            [a, b, c, d]
          RUBY
        },
      ],
      'hashes' => [
        { source: '{ one: "two" }' },
        { source: '{ :one => "two" }' },
        { source: '{ "one" => "two" }' },
        { source: 'key = :one; { key => "two" }' },
        { source: 'key = :one; value = "two"; { key => value }' },
      ],
      'symbols' => [
        {
          source: <<-'RUBY',
            version = 2
            :"v#{version}"
          RUBY
        }
      ],
      'regular expressions' => [
        {
          source: '/abcd/i',
        }
      ],
      'send' => [
        {
          source: "'fred durst'.split",
        },
        {
          source: 'self.nil?'
        },
        {
          metadata: :focus,
          source: <<~RUBY,
            value = false
            value.itself == false
          RUBY
        },
        {
          source: <<-RUBY,
            [1].map do |i|
              i + 1
            end
          RUBY
        },
        {
          title: 'when passing a block arg (Symbol#to_proc)',
          source: <<-RUBY,
            %w(1 2 3 4).map(&:to_i).reduce(&:+)
          RUBY
        },
        {
          title: 'when passing a block arg (proc)',
          source: <<-RUBY,
            block = proc { |char| char * 2 }
            'ab'.each_char.map(&block).join
          RUBY
        },
      ],
      'splats' => [
        {
          metadata: { skip: true },
          source: <<-RUBY,
            array = [1, 2, 3]
            [*array]
          RUBY
        },
        {
          source: <<-RUBY,
            array = [1, 2, 3]
            one, two, three, four = *array
            [one, two, three, four]
          RUBY
        },
        {
          source: <<-RUBY,
            args = [1, 2, 3]
            block = proc { |one, two, three| [three, two, one] }
            block.call(*args)
          RUBY
          expectation: [3, 2, 1],
        },
        # {
        #   metadata: :focus,
        #   source: <<-RUBY,
        #     # >> ar = [1,2,3]
        #     # => [1, 2, 3]
        #     # >> [*ar]
        #     # => [1, 2, 3]
        #     # >> [*ar.reverse]
        #     # => [3, 2, 1]
        #     args = [1, 2, 3]
        #     block = proc { |*nums| [*nums.reverse] }
        #     block.call(*args)
        #   RUBY
        # },
      ],
      'arg destructuring' => [
        # {
        #   metadata: :focus,
        #   source: <<-RUBY,
        #     args = [1, 2, 3]
        #     block = proc { |(one, two), three, four| [one, two, three, four] }
        #     block.call(*args)
        #   RUBY
        # },
      ],
      'ranges' => [
        { source: '0..3' },
        { source: '0...3' },
        { source: '0..-1' },
      ],
      'global variables' => [
        {
          source: '$stdout',
          expectation: nil,
          message: 'no globals should be defined by default',
        },
        {
          source: '$$',
          expectation: nil,
          message: 'no globals should be defined by default',
        },
      ],
      'constants' => [
        {
          source: 'self::INFINITY',
          context: Float,
        },
        {
          source: 'Float::INFINITY',
        },
      ],
    }.each_pair do |context_name, scenarios|
      context "with source including #{context_name}" do
        scenarios.each do |scenario|
          source, context, message = scenario.values_at(:source, :context, :message)
          expectation =
            if scenario.key?(:expectation)
              scenario[:expectation]
            else
              context.instance_eval(source)
            end

          it(
            scenario.fetch(:title, "results in #{expectation.inspect}"),
            scenario.fetch(:metadata, {})
          ) do
            result = Interpretr.run(source, context: context)

            expect(result).to eq(expectation), message || <<~MSG
              Expected:
                #{source}
              to evaluate to `#{expectation}`, but it evaluated to `#{result.inspect}`
            MSG
          end
        end
      end
    end

    context ''

  end

end
