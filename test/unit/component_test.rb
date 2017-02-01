require 'test_helper'

class ComponentTest < ActiveSupport::TestCase
    test "component builder" do
        actual = Component.build do
            click = click_event :run_command, "command"

            hover = hover_event :show_text do
                text "hover"
            end

            text color: :red, bold: true, click_event: click do
                text "text", color: :green, italic: true, hover_event: hover
                translate "translate" do
                    text "with"
                end
            end
        end.as_json

        expected = {
            'text' => '',
            'color' => 'red',
            'bold' => true,
            'clickEvent' => {
                'action' => 'run_command',
                'value' => 'command'
            },
            'extra' => [
                {
                    'text' => 'text',
                    'color' => 'green',
                    'italic' => true,
                    'hoverEvent' => {
                        'action' => 'show_text',
                        'value' => [
                            { 'text' => 'hover' }
                        ]
                    }
                },
                {
                    'translate' => 'translate',
                    'with' => [
                        { 'text' => 'with' }
                    ]
                }
            ]
        }

        assert_equal expected, actual
    end
end
