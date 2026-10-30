FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:username) { |n| "user_#{n}" }
    display_name { Faker::Name.name }
    password { "password123" }
  end
end
