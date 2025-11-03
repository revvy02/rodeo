local function entries<K, V>(map: { [K]: V }, keyIndex: any?, valueIndex: any?): { { [any]: K | V } }
    local useKeyIndex = if keyIndex == nil then 1 else keyIndex
    local useValueIndex = if valueIndex == nil then useKeyIndex + 1 else valueIndex

    local array = {}

    for key, value in map do
        table.insert(array, {
            [useKeyIndex] = key :: K | V,
            [useValueIndex] = value,
        })
    end

    return array
end

type EntriesFn =
    (<K, V>(map: { [K]: V }) -> { { K | V } })
    & (<K, V, T, U>(map: { [K]: V }, keyIndex: T, valueIndex: U) -> { { [T | U]: K | V } })

return entries :: EntriesFn
