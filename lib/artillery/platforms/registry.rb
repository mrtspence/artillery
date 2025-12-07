# frozen_string_literal: true

module Artillery
  module Platforms
    # Central registry for all artillery platform definitions
    # Platforms self-register when their class is loaded
    class Registry
      @platforms = {}

      class << self
        # Register a platform class
        # @param key [String, Symbol] Unique identifier for the platform
        # @param platform_class [Class] Platform class (must inherit from Base)
        def register(key, platform_class)
          @platforms[key.to_s] = platform_class
        end

        # Get a platform by key
        # @param key [String, Symbol] Platform identifier
        # @return [Class] Platform class
        # @raise [UnknownPlatformError] if platform not found
        def get(key)
          @platforms[key.to_s] || raise(UnknownPlatformError, key)
        end

        # Get all registered platforms
        # @return [Array<Class>] Array of platform classes
        def all
          @platforms.values
        end

        # Get all platform keys
        # @return [Array<String>] Array of platform keys
        def all_keys
          @platforms.keys
        end

        # Check if a platform is registered
        # @param key [String, Symbol] Platform identifier
        # @return [Boolean]
        def registered?(key)
          @platforms.key?(key.to_s)
        end
      end
    end
  end
end
