routes = case PGM::Application.ocn_role
    when 'octc'
        %w{ application server shop admin forem user }
    when 'avatar'
        %w{ avatar }
    when 'api'
        %w{ api }
    when 'worker'
        []
    else
        raise "Weird OCN_ROLE: #{PGM::Application.ocn_role}"
end

routes.each do |route|
    load "config/routes/#{route}.rb"
end
