FactoryBot.define do
  factory :message do
    transient do
      channel { association :channel }
      user { channel.created_by }
    end

    channel_id { channel.id }
    workspace_id { channel.workspace_id }
    user_id { user.id }
    sequence(:body) { |n| "Message number #{n}" }
  end
end
