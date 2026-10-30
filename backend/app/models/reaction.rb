# Embedded inside a Message document: reactions are always read together with
# their message, so embedding avoids a second query or collection.
class Reaction
  include Mongoid::Document

  embedded_in :message

  field :emoji, type: String
  field :user_ids, type: Array, default: []

  validates :emoji, presence: true, length: { maximum: 32 }
end
