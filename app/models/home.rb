class Home < ApplicationRecord
  belongs_to :user
  has_one :option, :dependent => :destroy
  has_many :reviews, :dependent => :destroy
  has_many :photos, :dependent => :destroy
  accepts_nested_attributes_for :option
  validates :address, presence: true, uniqueness: { case_sensitive: false }
  validates :description, length: { minimum: 10, maximum: 1400 }, presence: true
  validates :price, presence: true, numericality: true
  validates :size, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :available_rooms, numericality: true, allow_nil: true
  validates :total_bathrooms, numericality: true, allow_nil: true
  validates :private_bathrooms, numericality: true, allow_nil: true
  validates :is_furnished, inclusion: { in: [ true, false ] }
  validates :latitude, presence: true
  validates :longitude, presence: true

  validate :dates_cannot_be_in_the_past, :start_date_before_end_date

  geocoded_by :address
  before_validation :geocode, if: ->(obj){ obj.address.present? and obj.address_changed? and !obj.latitude? and !obj.longitude? }
  before_create :distance_matrix

  def dates_cannot_be_in_the_past
    today = Date.today
    if start_date < today
      errors.add(:start_date, "can't be in the past")
    end
    if end_date < today
      errors.add(:end_date, "can't be in the past")
    end
  end

  def start_date_before_end_date
    if end_date < start_date
      errors.add(:end_date, "cannot be before Start date")
    end
  end

  def distance_matrix
    modes = ['driving', 'bicycling', 'transit', 'walking']
    data_set = []
    matrix = GoogleDistanceMatrix::Matrix.new
    matrix.configure do |config|
      config.google_api_key = ENV['GOOGLE_KEY']
      config.units = 'imperial'
    end
    here = GoogleDistanceMatrix::Place.new lng: longitude, lat: latitude
    deis = GoogleDistanceMatrix::Place.new lng: -71.258663, lat: 42.364989
    matrix.origins << here
    matrix.destinations << deis
    modes.each_with_index do |mode, index|
      matrix.configuration.mode = mode
      matrix.reset!
      data_set[index] = matrix.data
    end
    # in miles and minutes
    self.driving_distance = to_integer(data_set[0][0][0].distance_text)
    self.driving_duration = to_integer(data_set[0][0][0].duration_text)
    self.bicycling_distance = to_integer(data_set[1][0][0].distance_text)
    self.bicycling_duration = to_integer(data_set[1][0][0].duration_text)
    self.transit_distance = to_integer(data_set[2][0][0].distance_text)
    self.transit_duration = to_integer(data_set[2][0][0].duration_text)
    self.walking_distance = to_integer(data_set[3][0][0].distance_text)
    self.walking_duration = to_integer(data_set[3][0][0].duration_text)
  end

  # provide select options for filters
  def self.options_for_sorted_by
    [
      ['Start date', 'start_date'],
      ['Price', 'price'],
      ['Size', 'size']
    ]
  end

  def self.options_for_furnished
    [
      ['Yes', 1],
      ['No', 0]
    ]
  end

  filterrific(
    default_filter_params: { sorted_by: 'start_date' },
    # filters go here
    available_filters: [
      :sorted_by,
      :with_availability_range,
      :with_price_range,
      :with_total_rooms_range,
      :with_available_rooms_range,
      :with_total_bathrooms_range,
      :with_private_bathrooms_range,
      :with_is_furnished,
      :with_driving_distance_range,
      :with_driving_duration_range,
      :with_bicycling_distance_range,
      :with_bicycling_duration_range,
      :with_transit_distance_range,
      :with_transit_duration_range,
      :with_walking_distance_range,
      :with_walking_duration_range
    ]
  )

  # sort options go here, default ascending
  scope :sorted_by, lambda { |sort_key|
    case sort_key.to_s
    when 'start_date'
      order("homes.start_date asc")
    when 'price'
      order("homes.price asc")
    when 'size'
      order("homes.size desc")
    else
      raise(ArgumentError, "Invalid sort option: #{ sort_key.inspect }")
    end
  }

  # date range of availability, can choose both start and end
  scope :with_availability_range, lambda { |date_range_attrs|
    start_date = Date.strptime(date_range_attrs.dates.split(' - ')[0], '%m/%d/%Y') rescue nil
    end_date = Date.strptime(date_range_attrs.dates.split(' - ')[1], '%m/%d/%Y') rescue nil

    if !start_date && !end_date
      return all
    elsif !start_date
      return where("end_date >= ?", end_date)
    elsif !end_date
      return where("start_date <= ?", start_date)
    end
    where("start_date <= ? AND end_date >= ?", start_date, end_date)
  }

  [:with_price_range, :with_total_rooms_range, :with_available_rooms_range, :with_private_bathrooms_range, :with_total_bathrooms_range, :with_driving_distance_range, :with_driving_duration_range, :with_bicycling_distance_range, :with_bicycling_duration_range, :with_transit_distance_range, :with_transit_duration_range, :with_walking_distance_range, :with_walking_duration_range].each do |sc|
    scope sc, lambda { |attrs|
      column = "#{sc.to_s[5..-7]}".to_sym
      if attrs.min.blank? && attrs.max.blank?
        return all
      elsif attrs.min.blank?
        return where(column => 0..attrs.max)
      elsif attrs.max.blank?
        return where(column => attrs.min..Float::INFINITY)
      end
      where(column => attrs.min..attrs.max)
    }
  end

  scope :with_is_furnished, lambda { |furnished|
    where(is_furnished: furnished)
  }

  private

    def to_integer(data)
      begin
        value = data.split(" ")
        if data.include? "hour"
          value = value[0].to_i*60 + value[2].to_i
        else
          value = value[0]
        end
        return value.to_i
      rescue
        return nil
      end
    end

end
