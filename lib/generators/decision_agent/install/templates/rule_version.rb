class RuleVersion < ApplicationRecord
  belongs_to :rule, primary_key: :rule_id, foreign_key: :rule_id, optional: true

  validates :rule_id, presence: true
  validates :version_number, presence: true, uniqueness: { scope: :rule_id }
  validates :content, presence: true
  validates :status, inclusion: { in: %w[draft active archived] }
  validates :created_by, presence: true

  scope :active, -> { where(status: 'active') }
  scope :for_rule, ->(rule_id) { where(rule_id: rule_id).order(version_number: :desc) }
  scope :latest, -> { order(version_number: :desc).limit(1) }

  before_create :set_next_version_number

  # Parse the JSON content
  def parsed_content
    JSON.parse(content, symbolize_names: true)
  rescue JSON::ParserError
    {}
  end

  # Set content from a hash
  def content_hash=(hash)
    self.content = hash.to_json
  end

  # Activate this version (deactivates others)
  def activate!
    transaction do
      # Deactivate all other versions for this rule
      # Use update! instead of update_all to trigger validations
      self.class.where(rule_id: rule_id, status: 'active')
                .where.not(id: id)
                .find_each do |v|
        v.update!(status: 'archived')
      end

      # Activate this version
      update!(status: 'active')
    end
  end

  # Compare with another version
  def compare_with(other_version)
    DecisionAgent::Versioning::VersionManager.new.compare(
      version_id_1: id,
      version_id_2: other_version.id
    )
  end

  private

  def set_next_version_number
    return if version_number.present?

    # Use pessimistic locking to prevent race conditions when calculating version numbers
    # Lock the last version record to ensure only one thread can read and increment at a time
    last_version = self.class.where(rule_id: rule_id)
                             .order(version_number: :desc)
                             .lock
                             .first

    self.version_number = last_version ? last_version.version_number + 1 : 1
  end
end
