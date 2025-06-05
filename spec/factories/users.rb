FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    role { :user }

    trait :admin do
      role { :admin }
    end

    trait :super_admin do
      role { :super_admin }
    end
  end
end
