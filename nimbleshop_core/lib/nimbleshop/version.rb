module Nimbleshop
  class Version
    @major = 0
    @minor = 0
    @tiny  = 10
    @build = nil

    class << self
      attr_reader :major, :minor, :tiny, :build

      def to_s
        [@major, @minor, @tiny, @build].compact.join('.')
      end
    end
  end

  RailsVersion = '= 3.2.8'
end
