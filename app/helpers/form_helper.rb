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

    # Render a Select2 form control for selecting multiple users,
    # featuring typeahead and all that fancy junk. The value
    # submitted by the form will be plain (unquoted) document IDs
    # delimited by commas e.g.
    #
    #        54856f8d744e7f90da000003,506119d8482629b455c44524,518853bfa878589b16000603
    #
    def user_multi_select_field(object_name, field_name, selection = [], **options)
        field_tag = ActionView::Helpers::Tags::HiddenField.new(object_name, field_name, self,
                                                               value: selection.map(&:id).join(','), **options)

        script = javascript_tag <<-JS
            $(document).ready(function() {
                $('##{field_tag.send(:tag_id)}').select2({
                    containerCssClass: 'form-control',
                    width: '100%',
                    multiple: true,
                    minimumInputLength: 1,
                    maximumInputLength: 16,
                    formatInputTooShort: "Start typing a name",
                    initSelection: function(element, callback) {
                        callback(#{ selection.map{|u| {id: u.id, text: u.username} }.to_json });
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
            });
        JS

        (field_tag.render + script).html_safe
    end
end
