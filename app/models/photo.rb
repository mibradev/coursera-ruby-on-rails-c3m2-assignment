require "exifr/jpeg"

class Photo
  attr_accessor :id
  attr_accessor :location
  attr_writer :contents

  class << self
    def mongo_client
      Mongoid::Clients.default
    end

    def all(offset = 0, limit = 0)
      mongo_client.database.fs.find.skip(offset).limit(limit).map { |document| new(document) }
    end

    def find(id)
      document = mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(id)).first
      new(document) if document
    end

    def find_photos_for_place(place_id)
      mongo_client.database.fs.find(:"metadata.place" => BSON::ObjectId.from_string(place_id))
    end
  end

  def initialize(options = {})
    self.id = options[:_id].to_s if options[:_id]

    if options[:metadata]
      self.location = Point.new(options[:metadata][:location])
      self.place = options[:metadata][:place]
    end
  end

  def contents
    file = self.class.mongo_client.database.fs.find_one(_id: BSON::ObjectId.from_string(id))
    file.chunks.inject("") { |buffer, chunk| buffer << chunk.data.data } if file
  end

  def place
    Place.find(@place) if @place
  end

  def place=(place)
    @place = place.is_a?(Place) ? BSON::ObjectId.from_string(place.id) : place
  end

  def persisted?
    self.id.present?
  end

  def find_nearest_place_id(max_meters)
    Place.near(location, max_meters).limit(1).projection(_id: 1).first[:_id]
  end

  def save
    description = { content_type: "image/jpeg", metadata: {} }
    description[:metadata][:place] = @place if @place

    unless persisted?
      if @contents
        gps = EXIFR::JPEG.new(@contents).gps
        @contents.rewind
        self.location = Point.new({ lng: gps.longitude, lat: gps.latitude })

        description[:metadata][:location] = location.to_hash
        grid_file = Mongo::Grid::File.new(@contents.read, description)
        self.id = self.class.mongo_client.database.fs.insert_one(grid_file).to_s
      end
    else
      description[:metadata][:location] = location.to_hash
      self.class.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(self.id)).update_one(description)
    end
  end

  def destroy
    self.class.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(id)).delete_one
  end
end
