# frozen_string_literal: true

module Artillery
  module Engines
    module Hooks
      module Flight
        class FlightHook
          def call!(state)
            raise NotImplementedError
          end
        end
      end
    end
  end
end
