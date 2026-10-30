require "rails_helper"

RSpec.describe Channel do
  let(:workspace) { create(:workspace) }

  it "normalizes names Slack-style" do
    channel = create(:channel, workspace: workspace, name: "  Design Team ")

    expect(channel.name).to eq("design-team")
  end

  it "requires unique names per workspace" do
    create(:channel, workspace: workspace, name: "design")

    expect(build(:channel, workspace: workspace, name: "design")).not_to be_valid
    expect(build(:channel, name: "design")).to be_valid
  end

  it "only lets workspace members join" do
    channel = create(:channel, workspace: workspace)
    outsider = create(:user)

    expect(channel.channel_memberships.build(user: outsider)).not_to be_valid
  end

  describe ".visible_to" do
    it "includes public channels and private channels the user belongs to" do
      member = add_member(workspace)
      secret = create(:channel, workspace: workspace, name: "secret", is_private: true)
      mine = create(:channel, workspace: workspace, name: "mine", is_private: true)
      mine.channel_memberships.create!(user: member)

      names = workspace.channels.visible_to(member).pluck(:name)

      expect(names).to include("general", "random", "mine")
      expect(names).not_to include(secret.name)
    end
  end
end
