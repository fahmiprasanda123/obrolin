FactoryBot.define do
  factory :channel do
    workspace
    sequence(:name) { |n| "channel-#{n}" }
    created_by { workspace.owner }
    is_private { false }

    after(:create) { |channel| channel.channel_memberships.create!(user: channel.created_by) }
  end
end
