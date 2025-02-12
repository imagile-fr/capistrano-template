module Capistrano
  module Template
    module Helpers
      class Renderer < SimpleDelegator
        attr_accessor :from, :reader, :locals

        def initialize(from, context, reader: File, locals: {})
          super context
          @scope = context
          self.from = from
          self.reader = reader
          self.locals = locals
        end

        def locals=(new_locals)
          new_locals ||= {}
          new_locals = new_locals.each_with_object({}) { |(key, value), result| result[key.to_sym] = value }
          @locals = new_locals
        end

        def as_str
          @rendered_template ||= begin
            ctx = ErbBinding.new(@scope, locals)
            ERB.new(template_content, trim_mode: '-').result(ctx.get_binding)
          end
        end

        def as_io
          StringIO.new(as_str)
        end

        def method_missing(method_name, *args, &block)
          if @scope.respond_to?(method_name)
            @scope.send(method_name, *args, &block)
          else
            super
          end
        end

        def render(from, indent: 0, locals: {})
          template = template_file(from)
          content  = Renderer.new(template, self, reader: reader, locals: self.locals.merge(locals)).as_str

          indented_content(content, indent)
        end

        def indented_content(content, indent)
          content.split("\n").map { |line| "#{' ' * indent}#{line}" }.join("\n")
        end

        def respond_to_missing?(method_name, include_private = false)
          @scope.respond_to?(method_name) || super
        end

        protected

        def template_content
          reader.read(from)
        end

        private

        class ErbBinding
          def initialize(scope, locals)
            @scope = scope
            locals.each do |key, value|
              singleton_class.define_method(key) { value }
            end
          end

          def method_missing(method_name, *args, &block)
            if @scope.respond_to?(method_name)
              @scope.send(method_name, *args, &block)
            else
              super
            end
          end

          def respond_to_missing?(method_name, include_private = false)
            @scope.respond_to?(method_name) || super
          end

          def get_binding
            binding
          end
        end
      end
    end
  end
end
