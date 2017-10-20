# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
User.create(name: "Tester", email: "test@test.com", password: "test", not_deis: false, notification_type: "email")

5.times do
  User.create(name: Faker::Name.name, email: Faker::Internet.email, password: Faker::Internet.password, not_deis: Faker::Boolean, notification_type: "email")
end

10.times do
  start_date = Faker::Date.between(Date.today, 2.years.from_now)
  end_date = Faker::Date.between(start_date, start_date + 2.years)
  Home.create(user_id: Faker::Number.between(1, 6), gallery_id: nil, notification_id: nil, option_id: nil,
  description: Faker::Company.bs, address: Faker::Company.bs, price: Faker::Number.decimal(3, 2),
  size: Faker::Number.decimal(3, 2), start_date: start_date, end_date: end_date, total_rooms: Faker::Number.between(1, 10),
  available_rooms: Faker::Number.between(1, 10), total_bathrooms: Faker::Number.between(1, 10),
  private_bathrooms: Faker::Number.between(1, 10), is_furnished: Faker::Boolean)
end
