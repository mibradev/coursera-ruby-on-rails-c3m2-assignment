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

    def get_address_components(sort = {}, offset = 0, limit = 0)
      q = collection.aggregate([
        { :$project => { :address_components => 1, :formatted_address => 1, :"geometry.geolocation" => 1 } },
        { :$unwind => "$address_components" }
      ])

      q.pipeline << { :$sort => sort } unless sort.empty?
      q.pipeline << { :$skip => offset } unless offset.zero?
      q.pipeline << { :$limit => limit } unless limit.zero?
      q
    end

    def get_country_names
      collection.aggregate([
        { :$project => { :"address_components.long_name" => 1, :"address_components.types" => 1 } },
        { :$unwind => "$address_components" },
        { :$match => { :"address_components.types" => "country" } },
        { :$group => { _id: "$address_components.long_name" } }
      ]).map { |document| document[:_id] }
    end

    def find_ids_by_country_code(country_code)
      collection.aggregate([
        { :$match => { :"address_components.short_name" => country_code } },
        { :$project => { _id: 1 } }
      ]).map { |document| document[:_id].to_s }
    end

    def create_indexes
      collection.indexes.create_one :"geometry.geolocation" => "2dsphere"
    end

    def remove_indexes
      collection.indexes.drop_one("geometry.geolocation_2dsphere")
    end

    def near(point, max_meters = 0)
      collection.find :"geometry.geolocation" => { :$near => { :$geometry => point.to_hash, :$maxDistance => max_meters } }
    end
  end

  def initialize(options)
    options[:address_components] ||= []

    self.id = options[:_id].to_s
    self.formatted_address = options[:formatted_address]
    self.location = Point.new(options[:geometry][:geolocation])
    self.address_components = options[:address_components].map { |a| AddressComponent.new(a) }
  end

  def destroy
    self.class.collection.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  def near(max_meters = 0)
    self.class.near(location, max_meters).map { |document| self.class.new(document) }
  end

  def photos(offset = 0, limit = 0)
    Photo.find_photos_for_place(id).skip(offset).limit(limit).map { |document| Photo.new(document) }
  end
end
