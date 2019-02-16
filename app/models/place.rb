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

    def all(offset = 0, limit = 0)
      collection.find.skip(offset).limit(limit).map { |document| new(document) }
    end

    def find(id)
      document = collection.find(_id: BSON::ObjectId.from_string(id)).first
      new(document) if document
    end

    def find_by_short_name(short_name)
      collection.find(:"address_components.short_name" => short_name)
    end

    def to_places(documents)
      documents.map { |document| new(document) }
    end
  end

  def initialize(options)
    self.id = options[:_id].to_s
    self.formatted_address = options[:formatted_address]
    self.location = Point.new(options[:geometry][:geolocation])
    self.address_components = options[:address_components].map { |a| AddressComponent.new(a) }
  end

  def destroy
    self.class.collection.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end
end
