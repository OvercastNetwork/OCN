module DeviseHelper
    def devise_error_messages!
        return "" if resource.errors.empty?

        messages = resource.errors.full_messages.map { |msg| content_tag(:li, msg) }.join
        sentence = I18n.t("errors.messages.not_saved", count: resource.errors.count, resource: resource.class.model_name.human.downcase)

        html = <<-HTML
        <div id="error_explanation">
            <h4>#{sentence}</h4>
            <ul>#{messages}</ul>
        </div>
        HTML

        html.html_safe
    end
end
