# Idempotent demo data: safe to run repeatedly with `bin/rails db:seed`.
# Every demo account uses the password "password123".
DEMO_PASSWORD = "password123".freeze

demo_users = [
  { username: "alice", display_name: "Alice Wijaya" },
  { username: "budi", display_name: "Budi Santoso" },
  { username: "citra", display_name: "Citra Lestari" },
  { username: "dimas", display_name: "Dimas Pratama" }
]

users = demo_users.to_h do |attrs|
  user = User.find_or_create_by!(username: attrs[:username]) do |u|
    u.email = "#{attrs[:username]}@obrolin.test"
    u.display_name = attrs[:display_name]
    u.password = DEMO_PASSWORD
  end
  [ attrs[:username].to_sym, user ]
end

workspace = Workspace.find_by(slug: "obrolin-demo")
if workspace
  puts "Demo workspace already exists, skipping workspace/messages."
else
  workspace = Workspace.create_with_owner!(owner: users[:alice], name: "Obrolin Demo")
  workspace.update!(slug: "obrolin-demo")
  workspace.add_member!(users[:budi], role: :admin)
  workspace.add_member!(users[:citra])
  workspace.add_member!(users[:dimas])

  general = workspace.channels.find_by!(name: "general")
  random = workspace.channels.find_by!(name: "random")

  engineering = workspace.channels.create!(name: "engineering", description: "Builds, deploys and code reviews",
                                           created_by: users[:budi])
  %i[budi alice dimas].each { |u| engineering.channel_memberships.create!(user: users[u]) }

  design = workspace.channels.create!(name: "design", description: "Private design discussions",
                                      created_by: users[:citra], is_private: true)
  %i[citra alice].each { |u| design.channel_memberships.create!(user: users[u]) }

  post = lambda do |channel, author, body, minutes_ago, parent: nil|
    message = Message.new(channel_id: channel.id, workspace_id: workspace.id, user_id: users[author].id,
                          body: body, parent_message_id: parent&.id,
                          created_at: minutes_ago.minutes.ago, updated_at: minutes_ago.minutes.ago)
    message.assign_mentions
    message.save!
    if parent
      parent.inc(reply_count: 1)
      parent.set(last_reply_at: message.created_at)
    end
    message
  end

  # Enough history in #general to try infinite scroll (page size is 30).
  40.times do |i|
    author = %i[alice budi citra dimas][i % 4]
    post.call(general, author, "Warm-up message ##{i + 1} so there is history to scroll through.", 600 - (i * 10))
  end

  welcome = post.call(general, :alice, "Welcome to Obrolin! 👋 This is the demo workspace.", 120)
  welcome.toggle_reaction!("👋", users[:budi].id)
  welcome.toggle_reaction!("👋", users[:citra].id)
  welcome.toggle_reaction!("🎉", users[:dimas].id)
  post.call(general, :budi, "Hi everyone! @citra can you share the new mockups?", 90)
  post.call(general, :citra, "Sure @budi, posting them in #design shortly.", 85)

  standup = post.call(engineering, :budi, "Standup: deploying the chat service to Kubernetes today.", 60)
  post.call(engineering, :alice, "Nice! Make sure the cable pods share Redis.", 55, parent: standup)
  post.call(engineering, :dimas, "Migrations ran fine on staging.", 50, parent: standup)
  post.call(engineering, :dimas, "Deploy finished, all pods are healthy ✅", 30)

  post.call(random, :dimas, "Anyone up for lunch? 🍜", 20)
  post.call(design, :citra, "New sidebar mockups are ready for review, @alice.", 15)

  # Leave some unread messages for alice in #general and #engineering.
  users[:alice].channel_memberships.update_all(last_read_at: 100.minutes.ago)
end

puts "Seeded #{User.count} users, #{Workspace.count} workspaces, #{Channel.count} channels, " \
     "#{Message.count} messages (password: #{DEMO_PASSWORD})"
