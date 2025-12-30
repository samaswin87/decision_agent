module DecisionAgent
  module Auth
    # Configuration class for RBAC adapter
    class RbacConfig
      attr_accessor :authenticator, :user_store

      def initialize
        @adapter = nil
        @authenticator = nil
        @user_store = nil
      end

      # Configure with a built-in adapter
      # @param adapter_type [Symbol] :default, :devise_cancan, :pundit, or :custom
      # @param options [Hash] Options for the adapter
      def use(adapter_type, **options)
        case adapter_type.to_sym
        when :default
          @adapter = DefaultAdapter.new
        when :devise_cancan
          @adapter = DeviseCanCanAdapter.new(**options)
        when :pundit
          @adapter = PunditAdapter.new(**options)
        when :custom
          @adapter = CustomAdapter.new(**options)
        else
          raise ArgumentError, "Unknown adapter type: #{adapter_type}. Use :default, :devise_cancan, :pundit, or :custom"
        end
        self
      end

      # Configure with a custom adapter instance
      # @param adapter_instance [RbacAdapter] An instance of RbacAdapter or subclass
      def adapter=(adapter_instance)
        raise ArgumentError, "Adapter must be an instance of DecisionAgent::Auth::RbacAdapter" unless adapter_instance.is_a?(RbacAdapter)

        @adapter = adapter_instance
      end

      # Get the configured adapter, or return default if none configured
      def adapter
        @adapter || DefaultAdapter.new
      end

      # Check if an adapter has been configured
      def configured?
        !@adapter.nil?
      end
    end
  end
end
