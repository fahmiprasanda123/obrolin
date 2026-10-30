require "rails_helper"

RSpec.describe Workspace do
  let(:owner) { create(:user) }

  describe ".create_with_owner!" do
    it "creates the owner membership and default channels" do
      workspace = described_class.create_with_owner!(owner: owner, name: "Acme Corp")

      expect(workspace.slug).to eq("acme-corp")
      expect(workspace.membership_for(owner)).to be_owner
      expect(workspace.channels.pluck(:name)).to contain_exactly("general", "random")
      expect(owner.channels.count).to eq(2)
    end

    it "generates a unique slug when the name is taken" do
      described_class.create_with_owner!(owner: owner, name: "Acme")
      second = described_class.create_with_owner!(owner: owner, name: "Acme")

      expect(second.slug).to match(/\Aacme-[a-z0-9]{4}\z/)
    end
  end

  describe "#add_member!" do
    it "joins the new member to default channels only" do
      workspace = create(:workspace)
      create(:channel, workspace: workspace, name: "secret", is_private: true)
      user = create(:user)

      workspace.add_member!(user)

      expect(user.channels.pluck(:name)).to contain_exactly("general", "random")
    end
  end
end
