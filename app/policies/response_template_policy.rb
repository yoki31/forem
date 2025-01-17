class ResponseTemplatePolicy < ApplicationPolicy
  PERMITTED_ATTRIBUTES = %i[content_type content title].freeze

  class Scope < Scope
    def resolve
      if Authorizer.for(user: user).accesses_mod_response_templates?
        scope.where(user: user, type_of: "personal_comment").or(scope.where.not(type_of: "personal_comment"))
      else
        scope.where(user: user, type_of: "personal_comment")
      end
    end
  end

  def index?
    true
  end

  def admin_index?
    user_any_admin?
  end

  def moderator_index?
    user_moderator? || user_trusted?
  end

  alias create? index?

  def admin_create?
    user.admin? || user.super_moderator?
  end

  # comes from comments_controller
  def use_template_for_moderator_comment?
    mod_comment? && (user_moderator? || user_trusted?)
  end
  alias moderator_create? use_template_for_moderator_comment?

  def modify?
    if user_owner?
      true
    else
      mod_comment? && (user.admin? || user.super_moderator?)
    end
  end

  alias update? modify?
  alias destroy? modify?

  def permitted_attributes_for_create
    if user_moderator?
      PERMITTED_ATTRIBUTES + [:type_of]
    else
      PERMITTED_ATTRIBUTES
    end
  end

  def permitted_attributes_for_update
    PERMITTED_ATTRIBUTES
  end

  private

  def user_owner?
    user.id == record.user_id
  end

  def user_trusted?
    Authorizer.for(user: user).accesses_mod_response_templates?
  end

  def user_moderator?
    user_any_admin? || user.super_moderator? || user.moderator_for_tags&.present?
  end

  def mod_comment?
    record.type_of == "mod_comment"
  end
end
