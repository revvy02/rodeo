local function isEmpty(value: { [any]: any }): boolean
    return next(value) == nil
end

return isEmpty
