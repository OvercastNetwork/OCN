class User
    module Perks
        extend ActiveSupport::Concern

        included do
            field :death_screen, type: String, default: nil

            attr_accessible :death_screen
            attr_accessible :death_screen, as: :user
            api_property :death_screen
        end

        module ClassMethods
            def death_screens
            {
                'default' => 'You died!',
                'luck' => 'Better luck next time!',
                'wrek' => 'Get wrecked!',
                'ez' => 'Ez...',
                'cry' => 'Wanna cry?',
                'who' => 'Who are you anyway?',
                'piece' => 'Wanna a piece of me?',
                'get' => 'Come and get me.',
                'noob' => 'Ha. Noob.',
                'miss' => 'Missed me?',
                'rage' => 'Are you a quitter?',
                'try' => 'Dont even try',
                'triple' => 'Oh baby a triple!',
                'suck' => 'Sucks to be you.',
                'even' => 'Do you even?',
                'ha' => 'Hahahaha...',
                'oops' => 'Oops. Didnt see you.',
                'cute' => 'Aww. How cute.',
                'dont' => 'Dont even try, bro.',
                'pvp' => 'You call that PvP?',
                'sword' => 'Try to swing next time.',
                'touch' => 'Cant touch dis...',
                'damn' => 'Dammmn son...',
                'hit' => 'Why you hitting yourself?',
                'cool' => '2 Cool 4 U',
                'up' => 'Just give up.'
            }
            end
        end

        def can_set_death_screen?
            death_screen != nil
        end
    end
end
