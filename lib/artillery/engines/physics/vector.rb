# frozen_string_literal: true

module Artillery
  module Physics
    class Vector
      attr_accessor :x, :y, :z

      def initialize(x = 0.0, y = 0.0, z = 0.0)
        @x = x
        @y = y
        @z = z
      end

      def self.from_array(arr)
        new(arr[0], arr[1], arr[2])
      end

      def +(other)
        self.class.new(@x + other.x, @y + other.y, @z + other.z)
      end

      def -(other)
        self.class.new(@x - other.x, @y - other.y, @z - other.z)
      end

      def *(scalar)
        self.class.new(@x * scalar, @y * scalar, @z * scalar)
      end

      def /(scalar)
        self.class.new(@x / scalar, @y / scalar, @z / scalar)
      end

      def magnitude
        Math.sqrt(@x**2 + @y**2 + @z**2)
      end

      def to_a
        [@x, @y, @z]
      end

      def dup
        self.class.new(@x, @y, @z)
      end

      def zero?
        @x.zero? && @y.zero? && @z.zero?
      end

      def inspect
        "#<Vector x=#{x.round(2)} y=#{y.round(2)} z=#{z.round(2)}>"
      end
    end
  end
end
