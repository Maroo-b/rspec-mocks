require 'rspec/mocks/verifying_proxy'

module RSpec
  module Mocks

    # @api private
    module VerifyingDouble
      def respond_to?(message, include_private=false)
        return super unless null_object?

        method_ref = __mock_proxy.method_reference[message]

        return case method_ref.visibility
          when :public    then true
          when :private   then include_private
          when :protected then include_private || RUBY_VERSION.to_f < 2.0
          else !method_ref.unimplemented?
        end
      end

      def method_missing(message, *args, &block)
        # Null object conditional is an optimization. If not a null object,
        # validity of method expectations will have been checked at definition
        # time.
        __mock_proxy.ensure_implemented(message) if null_object?
        super
      end
    end

    # A mock providing a custom proxy that can verify the validity of any
    # method stubs or expectations against the public instance methods of the
    # given class.
    # @api private
    class InstanceVerifyingDouble
      include TestDouble
      include VerifyingDouble

      def initialize(doubled_module, *args)
        @doubled_module = doubled_module

        __initialize_as_test_double(doubled_module, *args)
      end

      def __build_mock_proxy(order_group)
        VerifyingProxy.new(self, order_group,
          @doubled_module,
          InstanceMethodReference
        )
      end
    end

    # An awkward module necessary because we cannot otherwise have
    # ClassVerifyingDouble inherit from Module and still share these methods.
    # @api private
    module ObjectVerifyingDoubleMethods
      include TestDouble
      include VerifyingDouble

      def initialize(doubled_module, *args)
        @doubled_module = doubled_module

        __initialize_as_test_double(doubled_module, *args)
      end

      def __build_mock_proxy(order_group)
        VerifyingProxy.new(self, order_group,
          @doubled_module,
          ObjectMethodReference
        )
      end

      def as_stubbed_const(options = {})
        ConstantMutator.stub(@doubled_module.const_to_replace, self, options)
        self
      end
    end

    # Similar to an InstanceVerifyingDouble, except that it verifies against
    # public methods of the given object.
    # @api private
    class ObjectVerifyingDouble
      include ObjectVerifyingDoubleMethods
    end

    # Effectively the same as an ObjectVerifyingDouble (since a class is a type
    # of object), except with Module in the inheritance chain so that
    # transferring nested constants to work.
    # @api private
    class ClassVerifyingDouble < Module
      include ObjectVerifyingDoubleMethods
    end

  end
end
