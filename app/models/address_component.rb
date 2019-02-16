class AddressComponent
  attr_reader :long_name
  attr_reader :short_name
  attr_reader :types

  def initialize(options)
    @long_name = options[:long_name]
    @short_name = options[:short_name]
    @types = options[:types]
  end
end
