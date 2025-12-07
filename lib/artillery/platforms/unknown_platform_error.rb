# frozen_string_literal: true

module Artillery
  module Platforms
    class UnknownPlatformError < Error
      def initialize(platform_key)
        super("Unknown platform: '#{platform_key}'")
      end
    end
  end
end
