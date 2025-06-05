FactoryBot.define do
  factory :position do
    title { Faker::Job.title }
    description { Faker::Lorem.sentence }
    sequence(:level) { |n| n }
    association :department

    trait :with_parent do
      transient do
        parent_level { nil }
      end

      after(:build) do |position, evaluator|
        parent = create(:position, level: evaluator.parent_level || position.level + 1)
        position.parent_position = parent
      end
    end

    trait :with_employees do
      after(:create) do |position|
        create_list(:employee, 2, position: position)
      end
    end
  end
end 