module Gravatar
    class << self
        def email_hash(email)
            Digest::MD5.hexdigest(email.trim.downcase)
        end

        def url(email, size = 18)
            "https://gravatar.com/avatar/#{email_hash(email)}?s=#{size}"
        end
    end
end
