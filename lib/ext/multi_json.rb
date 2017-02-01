module MultiJson
    # Monkey-patch #load to support special float values by default
    # i.e. +/- Infinity and NaN
    def _ocn_load(string, options={})
        _ocn_original_load(string, {allow_nan: true}.merge(options))
    end
    alias_method :_ocn_original_load, :load
    alias_method :load, :_ocn_load
end
