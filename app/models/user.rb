class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, :lockable, :timeoutable,
         jwt_revocation_strategy: JwtDenylist

  enum role: {
    user: 0,
    admin: 1,
    super_admin: 2
  }

  validates :role, presence: true
  validate :password_complexity
  validate :password_expiration, on: :update

  # Associations
  has_one :employee
  has_many :managed_departments, through: :employee, source: :managed_department
  has_many :permissions, dependent: :destroy

  # Constants
  PASSWORD_REGEX = /\A
    (?=.*\d)           # Must contain a digit
    (?=.*[a-z])        # Must contain a lowercase letter
    (?=.*[A-Z])        # Must contain an uppercase letter
    (?=.*[[:^alnum:]]) # Must contain a symbol
  /x

  PASSWORD_EXPIRATION_DAYS = 90

  def jwt_payload
    {
      'email' => email,
      'role' => role,
      'employee_id' => employee&.id,
      'exp' => 24.hours.from_now.to_i
    }
  end

  # Permission methods
  def has_permission?(action, resource, resource_id = nil)
    return true if super_admin?
    return true if admin? && action == 'read'
    
    permissions.exists?(
      action: action,
      resource: resource,
      resource_id: [resource_id, nil]
    )
  end

  def grant_permission(action, resource, resource_id = nil)
    permissions.create!(
      action: action,
      resource: resource,
      resource_id: resource_id
    )
  end

  def revoke_permission(action, resource, resource_id = nil)
    permissions.where(
      action: action,
      resource: resource,
      resource_id: resource_id
    ).destroy_all
  end

  def grant_global_permission(resource)
    grant_permission('manage', resource)
  end

  def revoke_global_permission(resource)
    permissions.where(resource: resource, action: 'manage').destroy_all
  end

  def password_expired?
    return false if encrypted_password_changed_at.nil?
    encrypted_password_changed_at < PASSWORD_EXPIRATION_DAYS.days.ago
  end

  private

  def password_complexity
    return if password.blank?
    unless password.match?(PASSWORD_REGEX)
      errors.add :password, 'must include at least one lowercase letter, one uppercase letter, one digit, and one symbol'
    end
  end

  def password_expiration
    if password_expired? && !encrypted_password_changed?
      errors.add :password, 'has expired. Please change your password.'
    end
  end
end
