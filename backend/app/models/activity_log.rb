# Audit trail stored in MongoDB. Each action carries a different metadata
# shape, which is exactly where a schemaless document store shines.
class ActivityLog
  include Mongoid::Document
  include Mongoid::Timestamps

  field :actor_id, type: Integer
  field :workspace_id, type: Integer
  field :action, type: String
  field :target, type: Hash, default: {}    # { type: "Channel", id: 12 }
  field :metadata, type: Hash, default: {}

  index({ workspace_id: 1, created_at: -1 })
  index({ actor_id: 1, created_at: -1 })

  validates :action, presence: true

  def self.record(action, actor:, target: nil, workspace_id: nil, **metadata)
    create!(
      action: action,
      actor_id: actor&.id,
      workspace_id: workspace_id,
      target: target ? { type: target.class.name, id: target.id.to_s } : {},
      metadata: metadata
    )
  rescue Mongo::Error => e
    # Audit logging must never break the user-facing request.
    Rails.logger.warn("ActivityLog write failed: #{e.message}")
    nil
  end
end
