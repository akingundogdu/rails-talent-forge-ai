FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'Password1!' }
    password_confirmation { 'Password1!' }
    role { :user }

    trait :admin do
      role { :admin }
    end

    trait :super_admin do
      role { :super_admin }
    end
  end
end
