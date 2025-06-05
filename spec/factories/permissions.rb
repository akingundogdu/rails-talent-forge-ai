FactoryBot.define do
  factory :permission do
    association :user
    resource { Permission::RESOURCES.sample }
    action { Permission::ACTIONS.sample }
    resource_id { nil }

    trait :with_resource_id do
      resource_id { create(resource.to_sym).id }
    end

    trait :global do
      action { 'manage' }
      resource_id { nil }
    end

    trait :department do
      resource { 'department' }
      association :resource, factory: :department
    end

    trait :position do
      resource { 'position' }
      association :resource, factory: :position
    end

    trait :employee do
      resource { 'employee' }
      association :resource, factory: :employee
    end
  end
end 