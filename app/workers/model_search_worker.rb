class ModelSearchWorker
    include QueueWorker

    queue :api_request
    consumer manual_ack: false

    handle FindRequest do |req|
        req.model.search_response(request: req)
    end
end
