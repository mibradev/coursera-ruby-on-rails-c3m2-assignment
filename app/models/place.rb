class Place
  attr_accessor :id
  attr_accessor :formatted_address
  attr_accessor :location
  attr_accessor :address_components

  class << self
    def mongo_client
      Mongoid::Clients.default
    end

    def collection
      mongo_client[:places]
    end

    def load_all(file)
      collection.insert_many(JSON.load(file))
    end
  end

  def initialize(options)
    self.id = options[:_id].to_s
    self.formatted_address = options[:formatted_address]
    self.location = Point.new(options[:geometry][:geolocation])
    self.address_components = options[:address_components].map { |a| AddressComponent.new(a) }
  end
end
