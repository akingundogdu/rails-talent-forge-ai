class ApplicationPolicy
  include PermissionConcern
  
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    has_read_permission?
  end

  def create?
    has_create_permission?
  end

  def new?
    create?
  end

  def update?
    has_update_permission?
  end

  def edit?
    update?
  end

  def destroy?
    has_delete_permission?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if user.super_admin?
        scope.all
      elsif user.admin?
        scope.all
      else
        scope.joins(:permissions)
             .where(permissions: { user: user, action: ['read', 'manage'] })
             .or(scope.where(id: user.permissions.global.pluck(:resource_id)))
      end
    end

    private

    attr_reader :user, :scope
  end

  private

  def admin?
    user.admin?
  end

  def super_admin?
    user.super_admin?
  end

  def owns_record?
    record.user_id == user.id
  end

  def manages_department?
    return false unless user.employee
    user.managed_departments.include?(record)
  end
end 