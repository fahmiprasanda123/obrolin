class ApplicationController < ActionController::API
  include Authenticatable

  rescue_from ActiveRecord::RecordNotFound, Mongoid::Errors::DocumentNotFound do
    render json: { error: "Not found" }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: e.message }, status: :bad_request
  end

  private

  def render_forbidden(message = "You are not allowed to do that")
    render json: { error: message }, status: :forbidden
  end

  def render_validation_errors(record)
    render json: { errors: record.errors.to_hash(true) }, status: :unprocessable_content
  end
end
