module ApiControllerTest
    extend ActiveSupport::Concern

    included do
        setup do
            PGM::Application.ocn_role = 'api'
            request_header('Accept' => 'application/json')
            request_header('X-OCN-Version' => ApiModel.protocol_version.to_s)
        end

        teardown do
            PGM::Application.ocn_role = 'octc'
        end
    end
end

module ModelControllerTestBase
    extend ActiveSupport::Concern
    include ApiControllerTest

    # Guess the name of the model's testing factory
    def model_factory_name
        @controller.singular_name.to_sym
    end

    def create_model_instance
        create(model_factory_name)
    end

    def build_model_instance
        build(model_factory_name)
    end
end

module ModelControllerFindTest
    extend ActiveSupport::Concern
    include ModelControllerTestBase

    included do
        test "index" do
            docs = 3.times.map{ create_model_instance }
            get :index
            assert_json_collection documents: docs.map(&:api_document)
        end

        test "find" do
            doc = create_model_instance
            get :show, id: doc.id
            assert_json_response doc.api_document
        end

        test "find multi" do
            docs = 3.times.map{ create_model_instance }
            post :index, ids: docs.map(&:id)
            assert_json_collection documents: docs.map(&:api_document)
        end
    end
end

module ModelControllerUpdateTest
    extend ActiveSupport::Concern
    include ModelControllerTestBase

    included do
        test "update" do
            doc = build_model_instance
            json = doc.api_document
            post :update, id: doc.id, format: :json, document: json
            assert_equal json, doc.reload.api_document
        end
    end
end

module ModelControllerTest
    extend ActiveSupport::Concern
    include ModelControllerFindTest
    include ModelControllerUpdateTest
end
