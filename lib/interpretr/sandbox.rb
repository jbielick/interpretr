# frozen_string_literal: true

require 'logger'
require 'interpretr/context'
require 'interpretr/variables'

module Interpretr
  class Sandbox
    include ::Parser::AST::Processor::Mixin

    attr_reader :ast,
                :logger,
                :context,
                :lvars,
                :gvars,
                :ivars

    def initialize(ast)
      @logger = Logger.new(STDOUT)
      logger.level = Logger.const_get(ENV.fetch('INTERPRETR_LOG_LEVEL', 'WARN').upcase)
      @context = context
      @lvars = Variables.new(type: 'local')
      @gvars = Variables.new(type: 'global')
      @ast = ast
    end

    def run(context: nil, locals: {}, globals: {}, capabilities: Capabilities.new)
      @context = context
      @capabilities = capabilities
      gvars.with(globals) do
        lvars.with(locals) do
          process(ast)
        end
      end
    ensure
      @context = nil
      @capabilities = nil
      gvars.clear
      lvars.clear
    end

    private

    def process(node)
      return nil if node.nil?

      node = node.to_ast
      handler = "on_#{node.type}"
      __send__(handler, node)
    end

    def on_self(node)
      context
    end

    def on_send(node, &block)
      receiver_node, method_name, *arg_nodes = *node

      receiver = receiver_node.nil? ? context : process(receiver_node)

      if block_pass_in_args?(arg_nodes)
        block_pass_node = arg_nodes.pop
        if block && block_pass_node
          raise SyntaxError, "both block arg and actual block given"
        end
        block = process(block_pass_node)
      end

      logger.debug(<<~MSG.tr("\n", ""))
        (#{receiver_node&.type} #{receiver})
        .#{method_name}
        (#{arg_nodes.map(&:type).join(', ')})
        #{' { ... }' if block_given?}
      MSG

      # authorize_send!(receiver, method, node)
      receiver.__send__(method_name, *on_array(arg_nodes), &block)
    end
    alias on_csend on_send

    def on_const(node)
      parent_node, name = *node.children
      parent = process(parent_node)
      constant =
        if parent
          parent.const_get(name)
        else
          # this doesn't work
          context.const_get(name)
          # walk
        end
      # @TODO
      # authorize_constant!(constant, node)
      constant
    end

    # def on_casgn(node)
    #   scope_node, name, value_node = *node

    #   if !value_node.nil?
    #     node.updated(nil, [
    #       process(scope_node), name, process(value_node)
    #     ])
    #   else
    #     node.updated(nil, [
    #       process(scope_node), name
    #     ])
    #   end
    # end

    def block_pass_in_args?(arg_nodes)
      arg_nodes.any? && arg_nodes.last.type == :block_pass
    end

    def on_true(*)
      true
    end

    def on_false(*)
      false
    end

    def on_nil(*)
      nil
    end

    def leaf_value(node)
      node.children.first
    end

    alias on_str leaf_value
    alias on_int leaf_value
    alias on_float leaf_value
    alias on_sym leaf_value

    def on_dstr(node)
      process_all(node).join
    end

    def on_dsym(node)
      on_dstr(node).to_sym
    end

    alias on_regopt leaf_value
    def on_regexp(node)
      pattern, opts = process_all(node)
      Regexp.new(pattern, opts)
    end

    def on_xstr(node)
      fail
    end

    def on_splat(node)
      process(node.children.first)
    end

    # alias on_kwsplat  process_regular_node

    def on_array(node)
      child_nodes = *node
      child_nodes.reduce([]) do |memo, item_node|
        item = process(item_node)
        if item_node.type == :splat
          memo.push(*item)
        else
          memo.push(item)
        end
      end
    end

    def on_pair(node)
      process_all(node)
    end

    def on_hash(node)
      on_pair(node).to_h
    end

    def on_irange(node)
      lower, upper = process_all(node)
      (lower..upper)
    end

    def on_erange(node)
      lower, upper = process_all(node)
      (lower...upper)
    end

    def on_lvar(node)
      lvars.get!(leaf_value(node))
    end

    # alias on_ivar     process_variable_node

    def on_ivar(node)
      # @TODO ACL

    end

    def on_gvar(node)
      gvars.get(leaf_value(node)) { nil }
    end
    # alias on_cvar     process_variable_node
    # alias on_back_ref process_variable_node
    # alias on_nth_ref  process_variable_node

    # def on_vasgn(node)
    #   name, value_node = *node

    #   if !value_node.nil?
    #     node.updated(nil, [
    #       name, process(value_node)
    #     ])
    #   else
    #     node
    #   end
    # end

    # # @private
    # def process_var_asgn_node(node)
    #   on_vasgn(node)
    # end

    # alias on_lvasgn   process_var_asgn_node
    def on_lvasgn(node)
      name, value_node = *node
      lvars.set(name, process(value_node))
    end

    # alias on_ivasgn   process_var_asgn_node
    # alias on_gvasgn   process_var_asgn_node
    # alias on_cvasgn   process_var_asgn_node

    # alias on_and_asgn process_regular_node
    # alias on_or_asgn  process_regular_node

    # def on_op_asgn(node)
    #   var_node, method_name, value_node = *node

    #   node.updated(nil, [
    #     process(var_node), method_name, process(value_node)
    #   ])
    # end

    def on_mlhs(node)
      left_nodes = *node
      values = left_nodes.pop

      left_nodes.each do |left_node|
        value = values.shift
        case left_node.type
        when :lvasgn
          lvars.set(leaf_value(left_node), value)
        when :gvasgn
          gvars.set(leaf_value(left_node), value)
        when :splat
          lvars.set(leaf_value(leaf_value(left_node)), [value].concat(values))
        when :mlhs
          process(left_node.updated(nil, [
            *left_node.children,
            value
          ]))
        else
          raise NotImplementedError, "no set var implemented for #{left_node.type}!"
        end
      end
    end

    def on_masgn(node)
      left_node, right_node = *node
      value = process(right_node)
      values = value.respond_to?(:to_ary) ? value.to_ary : [value]

      process(
        left_node.updated(nil, [
          *left_node.children,
          values
        ])
      )
    end

    # alias on_rasgn    process_regular_node
    # alias on_mrasgn   process_regular_node

    def on_args(node)
      process_all(node)
    end
    alias on_arg leaf_value
    alias on_restarg leaf_value

    # alias on_optarg         process_argument_node
    # alias on_blockarg       process_argument_node
    # alias on_shadowarg      process_argument_node
    # alias on_kwarg          process_argument_node
    # alias on_kwoptarg       process_argument_node
    # alias on_kwrestarg      process_argument_node
    # alias on_forward_arg    process_argument_node

    # def on_procarg0(node)
    #   if node.children[0].is_a?(Symbol)
    #     # This branch gets executed when the builder
    #     # is not configured to emit and 'arg' inside 'procarg0', i.e. when
    #     #   Parser::Builders::Default.emit_arg_inside_procarg0
    #     # is set to false.
    #     #
    #     # If this flag is set to true this branch is unreachable.
    #     # s(:procarg0, :a)
    #     on_argument(node)
    #   else
    #     # s(:procarg0, s(:arg, :a), s(:arg, :b))
    #     process_regular_node(node)
    #   end
    # end

    # alias on_arg_expr       process_regular_node
    # alias on_restarg_expr   process_regular_node
    # alias on_blockarg_expr  process_regular_node
    # alias on_block_pass     process_regular_node
    def on_block_pass(node)
      process(leaf_value(node))
    end

    # alias on_module         process_regular_node
    # alias on_class          process_regular_node
    # alias on_sclass         process_regular_node

    # def on_def(node)
    #   name, args_node, body_node = *node

    #   node.updated(nil, [
    #     name,
    #     process(args_node), process(body_node)
    #   ])
    # end

    # def on_defs(node)
    #   definee_node, name, args_node, body_node = *node

    #   node.updated(nil, [
    #     process(definee_node), name,
    #     process(args_node), process(body_node)
    #   ])
    # end

    # alias on_undef    process_regular_node
    # alias on_alias    process_regular_node

    # alias on_index     process_regular_node
    # alias on_indexasgn process_regular_node

    def on_block(node)
      send_node, args_node, block_node = *node
      on_send(send_node) do |*block_args|
        # @TODO rest args, destructuring
        lvars.with(process(args_node).zip(block_args).to_h) do
          # assign_vars()

          process(block_node)
        end
      end
    end

    # alias on_lambda   process_regular_node

    # def on_numblock(node)
    #   method_call, max_numparam, body = *node

    #   node.updated(nil, [
    #     process(method_call), max_numparam, process(body)
    #   ])
    # end

    # alias on_while      process_regular_node
    # alias on_while_post process_regular_node
    # alias on_until      process_regular_node
    # alias on_until_post process_regular_node
    # alias on_for        process_regular_node

    # alias on_return   process_regular_node
    # alias on_break    process_regular_node
    # alias on_next     process_regular_node
    # alias on_redo     process_regular_node
    # alias on_retry    process_regular_node
    # alias on_super    process_regular_node
    # alias on_yield    process_regular_node
    # alias on_defined? process_regular_node

    # alias on_not      process_regular_node

    def on_and(node)
      left, right = process_all(node)
      left && right
    end

    def on_or(node)
      left, right = process_all(node)
      left || right
    end

    def on_if(node)
      expression, truthy_body, falsey_body = *node
      if process(expression)
        process(truthy_body)
      else
        process(falsey_body)
      end
    end

    # alias on_when     process_regular_node
    # alias on_case     process_regular_node

    # alias on_iflipflop process_regular_node
    # alias on_eflipflop process_regular_node

    # alias on_match_current_line process_regular_node
    # alias on_match_with_lvasgn  process_regular_node

    def on_resbody(node)
      _, _, result = process_all(node)
      result
    end

    # (rescue
    #   (send nil :name)
    #   (resbody nil nil
    #     (str "not defined")) nil)
    def on_rescue(node)
      wrapped_body_node, rescue_body_node = *node
      begin
        process(wrapped_body_node)
      rescue #type? => e?
        # lvars.with({ e?: error }) do
        process(rescue_body_node)
      end
    end
    # alias on_ensure   process_regular_node

    # alias on_begin    process_regular_node
    def on_begin(node)
      lvars.with({}) do
        process_all(node).last
      end
    end
    alias on_kwbegin  on_begin

    # alias on_preexe   process_regular_node
    # alias on_postexe  process_regular_node

    # alias on_case_match              process_regular_node
    # alias on_in_match                process_regular_node
    # alias on_in_pattern              process_regular_node
    # alias on_if_guard                process_regular_node
    # alias on_unless_guard            process_regular_node
    # alias on_match_var               process_variable_node
    # alias on_match_rest              process_regular_node
    # alias on_pin                     process_regular_node
    # alias on_match_alt               process_regular_node
    # alias on_match_as                process_regular_node
    # alias on_array_pattern           process_regular_node
    # alias on_array_pattern_with_tail process_regular_node
    # alias on_hash_pattern            process_regular_node
    # alias on_const_pattern           process_regular_node
    # alias on_find_pattern            process_regular_node

    # # @private
    # def process_variable_node(node)
    #   warn 'Parser::AST::Processor#process_variable_node is deprecated as a' \
    #     ' public API and will be removed. Please use ' \
    #     'Parser::AST::Processor#on_var instead.'
    #   on_var(node)
    # end

    # # @private
    # def process_var_asgn_node(node)
    #   warn 'Parser::AST::Processor#process_var_asgn_node is deprecated as a' \
    #     ' public API and will be removed. Please use ' \
    #     'Parser::AST::Processor#on_vasgn instead.'
    #   on_vasgn(node)
    # end

    # # @private
    # def process_argument_node(node)
    #   warn 'Parser::AST::Processor#process_argument_node is deprecated as a' \
    #     ' public API and will be removed. Please use ' \
    #     'Parser::AST::Processor#on_argument instead.'
    #   on_argument(node)
    # end

    # def on_empty_else(node)
    #   node
    # end

  end
end
