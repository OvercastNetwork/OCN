module FormHelper

    def user_select_field(object_name, field_name, selection = nil, placeholder: nil, **options)
        options[:'data-placeholder'] = placeholder if placeholder && !selection
        field_tag = ActionView::Helpers::Tags::TextField.new(object_name, field_name, self, options)

        script = javascript_tag <<-JS
            $('##{field_tag.send(:tag_id)}').select2({
                width: 'resolve',
                multiple: false,
                minimumInputLength: 1,
                maximumInputLength: 16,
                formatInputTooShort: "Start typing a name",
                initSelection: function(element, callback) {
                    callback(#{ selection && {id: selection.id, text: selection.username}.to_json });
                },
                ajax: {
                    url: #{ user_search_path.to_json },
                    dataType: 'json',
                    data: function(term, page) {
                        return {username: term};
                    },
                    results: function(data, page, query) {
                        return data;
                    }
                }
            });
            $('##{field_tag.send(:tag_id)}').val('#{selection && selection.id}');
        JS

        (field_tag.render + script).html_safe
    end

    def user_select_field2(object_name, field_name, collection = [], multiple = true, **options)
        model_select_field(User, object_name, field_name, :username, collection, multiple, options)
    end

    def server_select_field(object_name, field_name, collection = [], multiple = false, **options)
        model_select_field(Server, object_name, field_name, :name, collection, multiple, options)
    end

    # Render a Select2 form control for selecting multiple users,
    # featuring typeahead and all that fancy junk. The value
    # submitted by the form will be plain (unquoted) document IDs
    # delimited by commas.
    #
    # Object Parameters:
    #   object_name - the name of the object to modify (e.g. :server)
    #   select_field - the name of the field for the object to modify (e.g. :operator_ids)
    # Query Parameters:
    #   search_class - the model class to search for (e.g. User)
    #   search_field - the field to query for in the collection (e.g. :username)
    #
    def model_select_field(search_class, object_name, select_field, search_field, collection = [], multiple = true, **options)
        collection = collection.compact
        field_tag = ActionView::Helpers::Tags::HiddenField.new(object_name, select_field, self, value: collection.map(&:id).join(','), **options)
        script = javascript_tag <<-JS
            $(document).ready(function() {
                $('##{field_tag.send(:tag_id)}').select2({
                    containerCssClass: 'form-control',
                    width: '100%',
                    multiple: #{multiple},
                    minimumInputLength: 1,
                    maximumInputLength: 16,
                    formatInputTooShort: "Start typing a #{search_class.name} name",
                    initSelection: function(element, callback) {
                        callback(#{ collection.map{|model| {id: model.id, text: model[search_field]} }.to_json });
                    },
                    ajax: {
                        url: #{ model_search_path.to_json },
                        dataType: 'json',
                        data: function(term, page) {
                            return {request: term + ',#{search_class},#{search_field}'};
                        },
                        results: function(data, page, query) {
                            return data;
                        }
                    }
                });
            });
        JS
        (field_tag.render + script).html_safe
    end
end
