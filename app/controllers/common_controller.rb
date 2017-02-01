# Controller stuff common to website and API
class CommonController < ActionController::Base
    include ErrorHelper
    include BeforeRender

    around_filter :set_current_user
    after_filter :clear_request_cache

    rescue_from ErrorResponse do |ex|
        render_exception ex
    end

    rescue_from Mongoid::Errors::DocumentNotFound do |ex|
        render_exception NotFound.new
    end

    rescue_from Permissions::Denied do |ex|
        render_exception Forbidden.new
    end

    protected

    def render_exception(ex)
        render_error(ex.status, ex.message)
    end

    def render_error(status, message)
        render 'errors/show', status: status, layout: 'application', locals: {status: status, message: message}
    end

    def not_found
        raise NotFound
    end

    # Store the current user in a thread-local variable for the duration of the request
    def set_current_user
        User.with_current(current_user_safe) { yield }
    end

    def anonymous_user
        User.anonymous_user
    end

    def current_user_safe
        current_user || anonymous_user
    end

    def clear_request_cache
        Cache::RequestManager.clear_request_cache
    end
end
