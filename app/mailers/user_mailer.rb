class UserMailer < OrganizationMailer
    def inquiry_notification(name, email, subject, type, message)
        @name = name
        @email = email
        @subject = subject
        @type = type
        @message = message

        mail(to: ORG::EMAIL, reply_to: email, subject: "#{type}: #{subject}")
    end

    def donation_notification(payer, receiver, email)
        @payer = payer
        @receiver = receiver
        @email = email

        mail(to: email, subject: "Thank You!")
    end

    def transaction_receipt(trans)
        @trans = trans
        @package = trans.purchase.package.name
        @price = "$#{trans.formatted_dollars} USD"
        @buyer = trans.user.username if trans.user
        @recipient = trans.purchase.recipient.username
        @self = trans.user == trans.purchase.recipient

        mail(to: trans.email,
             reply_to: ORG::EMAIL,
             subject: "Receipt for #{@package} premium package (transaction #{trans.id})")
    end

    def team_name_change(team)
        @team = team
        @leader = User.by_player_id(@team.leader) or raise "Unknown leader #{@team.leader}"

        mail(to: @leader.email, subject: "Your team has been renamed")
    end
end
