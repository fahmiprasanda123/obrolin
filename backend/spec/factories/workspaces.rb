FactoryBot.define do
  factory :workspace do
    sequence(:name) { |n| "Workspace #{n}" }
    association :owner, factory: :user

    # Goes through the real creation path (owner membership + default channels).
    to_create do |instance|
      created = Workspace.create_with_owner!(owner: instance.owner, name: instance.name)
      instance.id = created.id
      instance.reload
    end
  end
end
