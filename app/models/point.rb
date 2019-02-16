class Point
  attr_accessor :longitude
  attr_accessor :latitude

  def initialize(options)
    if options[:type] == "Point" && options[:coordinates]
      self.longitude = options[:coordinates][0]
      self.latitude = options[:coordinates][1]
    elsif options[:lng] && options[:lat]
      self.longitude = options[:lng]
      self.latitude = options[:lat]
    end
  end

  def to_hash
    { type: "Point", coordinates: [longitude, latitude] }
  end
end
