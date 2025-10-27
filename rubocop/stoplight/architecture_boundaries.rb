# frozen_string_literal: true

module RuboCop
  module Cop
    module Stoplight
      class ArchitectureBoundaries < Base
        MSG = "%{current_layer} cannot depend on %{forbidden_layer}"
        MSG_SPEC = "%{current_layer} cannot depend on %{forbidden_layer} (use domain interface in test doubles instead)"

        LAYER_NAMES = %i[Domain Infrastructure Wiring Admin].freeze

        LAYER_PATTERNS = {
          domain: %r{(lib|spec)/stoplight/domain},
          infrastructure: %r{(lib|spec)/stoplight/infrastructure},
          wiring: %r{(lib|spec)/stoplight/wiring},
          admin: %r{(lib|spec)/stoplight/admin}
        }.freeze

        ALLOWED_DEPENDENCIES = {
          domain: [],
          infrastructure: [:domain],
          wiring: [:domain, :infrastructure],
          admin: [:domain, :infrastructure, :wiring]
        }.freeze

        # Methods where the constant in describe/context is allowed
        # (for describing what you're testing)
        RSPEC_DESCRIBE_METHODS = %i[describe context].to_set.freeze

        # Methods where we allow the receiver but still check arguments
        RSPEC_STUB_METHODS = %i[
          allow allow_any_instance_of
          expect expect_any_instance_of
          receive receive_messages receive_message_chain
        ].to_set.freeze

        def on_new_investigation
          @current_layer = detect_layer(processed_source.file_path)
          return unless @current_layer

          @allowed_layers = ALLOWED_DEPENDENCIES[@current_layer]
          @namespace_stack = []
          @is_spec_file = processed_source.file_path.include?("spec/")
        end

        def on_module(node)
          module_name = extract_module_name(node)
          @namespace_stack.push(module_name) if module_name

          node.each_child_node { |child| process(child) }

          @namespace_stack.pop if module_name
        end

        def on_class(node)
          class_name = extract_class_name(node)
          @namespace_stack.push(class_name) if class_name

          node.each_child_node { |child| process(child) }

          @namespace_stack.pop if class_name
        end

        def on_const(node)
          return if node.parent&.const_type?
          return if in_allowed_context?(node)

          check_constant_reference(node)
        end

        def on_send(node)
          # Allow constants in describe/context blocks (for described_class)
          if RSPEC_DESCRIBE_METHODS.include?(node.method_name)
            # Don't check the first argument (the class being described)
            # but check everything else
            return
          end

          # For stub methods, check the receiver is allowed but not the method name
          if RSPEC_STUB_METHODS.include?(node.method_name)
            # Only process the receiver, not the arguments
            process(node.receiver) if node.receiver
            return
          end

          # Check include/extend/prepend
          if [:include, :extend, :prepend].include?(node.method_name)
            node.arguments.each do |arg|
              check_constant_reference(arg) if arg.const_type?
            end
          end
        end

        private

        def in_allowed_context?(node)
          # Allow constants as first argument to describe/context
          parent = node.parent
          if parent&.send_type? && RSPEC_DESCRIBE_METHODS.include?(parent.method_name)
            # Check if this const is the first argument
            return true if parent.arguments.first == node || parent.arguments.first&.children&.include?(node)
          end

          # Allow constants in stub_const first argument (the string name)
          if parent&.send_type? && parent.method_name == :stub_const
            return true if parent.arguments.first == node
          end

          false
        end

        def extract_module_name(node)
          return nil unless node.module_definition?
          identifier = node.identifier
          identifier.const_name if identifier.respond_to?(:const_name)
        end

        def extract_class_name(node)
          return nil unless node.class_definition?
          identifier = node.identifier
          identifier.const_name if identifier.respond_to?(:const_name)
        end

        def check_constant_reference(node)
          return unless node.const_type?
          return unless @current_layer

          const_path = extract_constant_path(node)
          return unless const_path

          resolved_namespace = resolve_namespace(const_path)
          return unless resolved_namespace

          forbidden_layer = extract_forbidden_layer(resolved_namespace)
          return unless forbidden_layer

          # Use different message for spec files vs production code
          message_template = @is_spec_file ? MSG_SPEC : MSG

          add_offense(
            node,
            message: format(
              message_template,
              current_layer: @current_layer,
              forbidden_layer: forbidden_layer
            )
          )
        end

        def extract_constant_path(node)
          parts = []
          current = node

          while current
            case current.type
            when :const
              parts.unshift(current.children[1].to_s)
              current = current.children[0]
            when :cbase
              return parts.join("::")
            else
              return parts.join("::")
            end
          end

          parts.join("::")
        end

        def resolve_namespace(const_path)
          first_segment = const_path.split("::").first

          if LAYER_NAMES.map(&:to_s).include?(first_segment)
            return "Stoplight::#{const_path}"
          end

          if const_path.start_with?("Stoplight::")
            return const_path
          end

          if @namespace_stack.include?("Stoplight")
            if LAYER_NAMES.map(&:to_s).include?(first_segment)
              return "Stoplight::#{const_path}"
            end
          end

          const_path
        end

        def extract_forbidden_layer(namespace)
          match = namespace.match(/Stoplight::(Domain|Infrastructure|Wiring|Admin)/)
          return nil unless match

          layer_name = match[1].downcase.to_sym

          return nil if layer_name == @current_layer
          return nil if @allowed_layers.include?(layer_name)

          layer_name
        end

        def detect_layer(file_path)
          LAYER_PATTERNS.find { |layer, pattern| file_path.match?(pattern) }&.first
        end

        def process(node)
          return unless node.is_a?(Parser::AST::Node)

          case node.type
          when :module
            on_module(node)
          when :class
            on_class(node)
          when :const
            on_const(node)
          when :send
            on_send(node)
          else
            node.each_child_node { |child| process(child) }
          end
        end
      end
    end
  end
end
