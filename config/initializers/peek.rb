if PGM::Application.ocn_role == 'octc'
    Peek.into Peek::Views::Git
    Peek.into Peek::Views::PerformanceBar
    Peek.into Peek::Views::Redis
    Peek.into Peek::Views::Rblineprof
end
