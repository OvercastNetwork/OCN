module AdminControllerTestHelper
    def setup
        super

        @admin = create(:user, username: "Admin", admin: true)
        sign_in @admin
    end
end
