# Assign symbols to globals for every Mongo keyword

%w{
    gt gte in lt lte ne	nin
    not or and nor
    exists type
    mod regex text where
    all elemMatch size
    meta slice
    currentDate inc max min mul rename setOnInsert set unset
    addToSet pop pullAll pull pushAll push
    each position sort
    bit
    isolated
    geoNear group limit match out project redact skip unwind
    allElementsTrue anyElementTrue setDifference setEquals setIntersection setIsSubset setUnion
    cmp
    add divide multiply subtract
    concat strcasecmp substr toLower toUpper
    let map
    literal
    dayOfMonth dayOfWeek dayOfYear hour millisecond minute month second week year
    cond ifNull
    avg first last sum
    comment explain hint maxScan maxTimeMS orderby query returnKey showDiskLoc snapshot
    natural
}.each do |op|
    eval "$#{op} = :'$#{op}'"
end
