# frozen_string_literal: true

module Artillery
  module Engines
    module Affectors
      class Base
        class << self
          def call(...)
            new(...).call!
          end
        end

        def call!
          raise NotImplementedError, "#{self.class.name} must implement #call!"
        end
      end
    end
  end
end
